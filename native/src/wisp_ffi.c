/*
 * Wisp FFI Implementation
 * C bindings for libcurl with external class registration
 */

#include "wisp_ffi.h"
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdint.h>

// ============================================================================
// External Class Registration
// ============================================================================

static lean_external_class* g_easy_class = NULL;
static lean_external_class* g_multi_class = NULL;
static lean_external_class* g_slist_class = NULL;
static lean_external_class* g_mime_class = NULL;
static lean_external_class* g_mimepart_class = NULL;

static int g_initialized = 0;

// ============================================================================
// Wrapper Types
// ============================================================================

typedef struct {
    CURL* handle;
    char* response_body;
    size_t response_size;
    size_t response_capacity;
    char* response_headers;
    size_t headers_size;
    size_t headers_capacity;
    char** option_strings;
    size_t option_strings_count;
    size_t option_strings_capacity;
    struct curl_slist* owned_slist;
    curl_mime* owned_mime;
    // Streaming support
    int is_streaming;           // 0=buffered (default), 1=streaming
    size_t stream_read_offset;  // How much body data has been read by Lean
    int headers_complete;       // 1 if all headers received
} EasyWrapper;

typedef struct {
    CURLM* handle;
} MultiWrapper;

typedef struct {
    struct curl_slist* list;
} SlistWrapper;

typedef struct {
    curl_mime* mime;
    CURL* easy;
} MimeWrapper;

typedef struct {
    curl_mimepart* part;
} MimepartWrapper;

// ============================================================================
// Finalizers
// ============================================================================

static void easy_finalizer(void* ptr) {
    EasyWrapper* wrapper = (EasyWrapper*)ptr;
    if (wrapper) {
        if (wrapper->handle) curl_easy_cleanup(wrapper->handle);
        if (wrapper->response_body) free(wrapper->response_body);
        if (wrapper->response_headers) free(wrapper->response_headers);
        if (wrapper->option_strings) {
            for (size_t i = 0; i < wrapper->option_strings_count; i++) {
                free(wrapper->option_strings[i]);
            }
            free(wrapper->option_strings);
        }
        if (wrapper->owned_slist) curl_slist_free_all(wrapper->owned_slist);
        if (wrapper->owned_mime) curl_mime_free(wrapper->owned_mime);
        free(wrapper);
    }
}

static void multi_finalizer(void* ptr) {
    MultiWrapper* wrapper = (MultiWrapper*)ptr;
    if (wrapper) {
        if (wrapper->handle) curl_multi_cleanup(wrapper->handle);
        free(wrapper);
    }
}

static void slist_finalizer(void* ptr) {
    SlistWrapper* wrapper = (SlistWrapper*)ptr;
    if (wrapper) {
        if (wrapper->list) curl_slist_free_all(wrapper->list);
        free(wrapper);
    }
}

static void mime_finalizer(void* ptr) {
    MimeWrapper* wrapper = (MimeWrapper*)ptr;
    if (wrapper) {
        if (wrapper->mime) curl_mime_free(wrapper->mime);
        free(wrapper);
    }
}

static void mimepart_finalizer(void* ptr) {
    // Mimeparts are freed with their parent mime
    free(ptr);
}

static void noop_foreach(void* ptr, b_lean_obj_arg arg) {
    (void)ptr;
    (void)arg;
}

// ============================================================================
// Helper Functions
// ============================================================================

static void init_external_classes(void) {
    if (g_easy_class == NULL) {
        g_easy_class = lean_register_external_class(easy_finalizer, noop_foreach);
        g_multi_class = lean_register_external_class(multi_finalizer, noop_foreach);
        g_slist_class = lean_register_external_class(slist_finalizer, noop_foreach);
        g_mime_class = lean_register_external_class(mime_finalizer, noop_foreach);
        g_mimepart_class = lean_register_external_class(mimepart_finalizer, noop_foreach);
    }
}

static lean_object* mk_io_error(const char* msg) {
    return lean_io_result_mk_error(lean_mk_io_user_error(lean_mk_string(msg)));
}

static lean_object* mk_curl_error(CURLcode code) {
    char msg[256];
    snprintf(msg, sizeof(msg), "CURL error %d: %s", code, curl_easy_strerror(code));
    return lean_io_result_mk_error(lean_mk_io_user_error(lean_mk_string(msg)));
}

static lean_object* mk_curlm_error(CURLMcode code) {
    char msg[256];
    snprintf(msg, sizeof(msg), "CURLM error %d: %s", code, curl_multi_strerror(code));
    return lean_io_result_mk_error(lean_mk_io_user_error(lean_mk_string(msg)));
}

static void easy_store_string(EasyWrapper* wrapper, char* str) {
    if (!str) return;
    if (wrapper->option_strings_count == wrapper->option_strings_capacity) {
        size_t new_capacity = wrapper->option_strings_capacity == 0 ? 8 : wrapper->option_strings_capacity * 2;
        char** new_list = realloc(wrapper->option_strings, new_capacity * sizeof(char*));
        if (!new_list) {
            free(str);
            return;
        }
        wrapper->option_strings = new_list;
        wrapper->option_strings_capacity = new_capacity;
    }
    wrapper->option_strings[wrapper->option_strings_count++] = str;
}

static void easy_clear_strings(EasyWrapper* wrapper) {
    if (!wrapper->option_strings) return;
    for (size_t i = 0; i < wrapper->option_strings_count; i++) {
        free(wrapper->option_strings[i]);
    }
    wrapper->option_strings_count = 0;
}

static void easy_clear_owned_handles(EasyWrapper* wrapper) {
    if (wrapper->owned_slist) {
        curl_slist_free_all(wrapper->owned_slist);
        wrapper->owned_slist = NULL;
    }
    if (wrapper->owned_mime) {
        curl_mime_free(wrapper->owned_mime);
        wrapper->owned_mime = NULL;
    }
}

// Find CA bundle (same logic as afferent)
static const char* find_ca_bundle(void) {
    const char* envs[] = {
        "WISP_CA_BUNDLE",
        "CURL_CA_BUNDLE",
        "SSL_CERT_FILE"
    };

    for (size_t i = 0; i < sizeof(envs) / sizeof(envs[0]); i++) {
        const char* val = getenv(envs[i]);
        if (val && val[0] && access(val, R_OK) == 0) {
            return val;
        }
    }

    const char* candidates[] = {
        "/etc/ssl/cert.pem",                    // macOS
        "/etc/ssl/certs/ca-certificates.crt",   // Debian/Ubuntu
        "/etc/pki/tls/certs/ca-bundle.crt",     // RHEL/CentOS/Fedora
        "/etc/ssl/ca-bundle.pem"                // SLES/openSUSE
    };

    for (size_t i = 0; i < sizeof(candidates) / sizeof(candidates[0]); i++) {
        if (access(candidates[i], R_OK) == 0) {
            return candidates[i];
        }
    }

    return NULL;
}

// ============================================================================
// Write Callbacks
// ============================================================================

static size_t write_callback(void* contents, size_t size, size_t nmemb, void* userp) {
    size_t realsize = size * nmemb;
    EasyWrapper* wrapper = (EasyWrapper*)userp;

    // Grow buffer if needed
    size_t needed = wrapper->response_size + realsize + 1;
    if (needed > wrapper->response_capacity) {
        size_t new_capacity = wrapper->response_capacity == 0 ? 4096 : wrapper->response_capacity * 2;
        while (new_capacity < needed) new_capacity *= 2;

        char* ptr = realloc(wrapper->response_body, new_capacity);
        if (!ptr) return 0;

        wrapper->response_body = ptr;
        wrapper->response_capacity = new_capacity;
    }

    memcpy(wrapper->response_body + wrapper->response_size, contents, realsize);
    wrapper->response_size += realsize;
    wrapper->response_body[wrapper->response_size] = 0;

    return realsize;
}

static size_t header_callback(void* contents, size_t size, size_t nmemb, void* userp) {
    size_t realsize = size * nmemb;
    EasyWrapper* wrapper = (EasyWrapper*)userp;

    // Grow buffer if needed
    size_t needed = wrapper->headers_size + realsize + 1;
    if (needed > wrapper->headers_capacity) {
        size_t new_capacity = wrapper->headers_capacity == 0 ? 2048 : wrapper->headers_capacity * 2;
        while (new_capacity < needed) new_capacity *= 2;

        char* ptr = realloc(wrapper->response_headers, new_capacity);
        if (!ptr) return 0;

        wrapper->response_headers = ptr;
        wrapper->headers_capacity = new_capacity;
    }

    memcpy(wrapper->response_headers + wrapper->headers_size, contents, realsize);
    wrapper->headers_size += realsize;
    wrapper->response_headers[wrapper->headers_size] = 0;

    // Check if headers are complete (blank line = just "\r\n")
    // This signals the end of headers and start of body
    if (realsize == 2 && ((char*)contents)[0] == '\r' && ((char*)contents)[1] == '\n') {
        wrapper->headers_complete = 1;
    }

    return realsize;
}

// ============================================================================
// Initialization
// ============================================================================

LEAN_EXPORT lean_obj_res wisp_global_init(lean_obj_arg world) {
    if (!g_initialized) {
        CURLcode res = curl_global_init(CURL_GLOBAL_DEFAULT);
        if (res != CURLE_OK) {
            return mk_io_error("Failed to initialize libcurl");
        }
        init_external_classes();
        g_initialized = 1;
    }
    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_obj_res wisp_global_cleanup(lean_obj_arg world) {
    if (g_initialized) {
        curl_global_cleanup();
        g_initialized = 0;
    }
    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_obj_res wisp_version_info(lean_obj_arg world) {
    curl_version_info_data* info = curl_version_info(CURLVERSION_NOW);

    char buf[1024];
    snprintf(buf, sizeof(buf),
        "libcurl %s (SSL: %s, zlib: %s, protocols: %s%s%s%s%s)",
        info->version,
        info->ssl_version ? info->ssl_version : "none",
        info->libz_version ? info->libz_version : "none",
        info->protocols[0] ? info->protocols[0] : "",
        info->protocols[1] ? ", " : "",
        info->protocols[1] ? info->protocols[1] : "",
        info->protocols[2] ? ", " : "",
        info->protocols[2] ? info->protocols[2] : "");

    return lean_io_result_mk_ok(lean_mk_string(buf));
}

// ============================================================================
// Easy Handle Operations
// ============================================================================

LEAN_EXPORT lean_obj_res wisp_easy_init(lean_obj_arg world) {
    if (!g_initialized) {
        lean_object* init_result = wisp_global_init(lean_box(0));
        lean_dec(init_result);
    }

    CURL* handle = curl_easy_init();
    if (!handle) {
        return mk_io_error("Failed to create CURL easy handle");
    }

    // Set default CA bundle
    const char* ca_bundle = find_ca_bundle();
    if (ca_bundle) {
        curl_easy_setopt(handle, CURLOPT_CAINFO, ca_bundle);
    }

    EasyWrapper* wrapper = calloc(1, sizeof(EasyWrapper));
    if (!wrapper) {
        curl_easy_cleanup(handle);
        return mk_io_error("Failed to allocate EasyWrapper");
    }
    wrapper->handle = handle;

    lean_object* obj = lean_alloc_external(g_easy_class, wrapper);
    return lean_io_result_mk_ok(obj);
}

LEAN_EXPORT lean_obj_res wisp_easy_cleanup(b_lean_obj_arg easy, lean_obj_arg world) {
    // Cleanup is handled by finalizer, this is a no-op
    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_obj_res wisp_easy_reset(b_lean_obj_arg easy, lean_obj_arg world) {
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy);
    curl_easy_reset(wrapper->handle);
    easy_clear_strings(wrapper);
    easy_clear_owned_handles(wrapper);

    // Reset response buffers
    if (wrapper->response_body) {
        free(wrapper->response_body);
        wrapper->response_body = NULL;
        wrapper->response_size = 0;
        wrapper->response_capacity = 0;
    }
    if (wrapper->response_headers) {
        free(wrapper->response_headers);
        wrapper->response_headers = NULL;
        wrapper->headers_size = 0;
        wrapper->headers_capacity = 0;
    }

    // Re-set CA bundle
    const char* ca_bundle = find_ca_bundle();
    if (ca_bundle) {
        curl_easy_setopt(wrapper->handle, CURLOPT_CAINFO, ca_bundle);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_obj_res wisp_easy_perform(b_lean_obj_arg easy, lean_obj_arg world) {
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy);

    // Reset response buffers before performing
    wrapper->response_size = 0;
    wrapper->headers_size = 0;

    CURLcode res = curl_easy_perform(wrapper->handle);
    if (res != CURLE_OK) {
        return mk_curl_error(res);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

// ============================================================================
// Setopt Operations
// ============================================================================

LEAN_EXPORT lean_obj_res wisp_easy_setopt_string(
    b_lean_obj_arg easy,
    uint32_t option,
    b_lean_obj_arg value,
    lean_obj_arg world
) {
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy);
    const char* str = lean_string_cstr(value);
    char* str_copy = strdup(str);
    if (!str_copy) {
        return mk_io_error("Failed to allocate string");
    }

    CURLcode res = curl_easy_setopt(wrapper->handle, (CURLoption)option, str_copy);
    if (res != CURLE_OK) {
        free(str_copy);
        return mk_curl_error(res);
    }

    easy_store_string(wrapper, str_copy);
    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_obj_res wisp_easy_setopt_private(
    b_lean_obj_arg easy,
    uint64_t value,
    lean_obj_arg world
) {
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy);
    void* ptr = (void*)(uintptr_t)value;

    CURLcode res = curl_easy_setopt(wrapper->handle, CURLOPT_PRIVATE, ptr);
    if (res != CURLE_OK) {
        return mk_curl_error(res);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_obj_res wisp_easy_setopt_long(
    b_lean_obj_arg easy,
    uint32_t option,
    int64_t value,
    lean_obj_arg world
) {
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy);

    CURLcode res = curl_easy_setopt(wrapper->handle, (CURLoption)option, (long)value);
    if (res != CURLE_OK) {
        return mk_curl_error(res);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_obj_res wisp_easy_setopt_slist(
    b_lean_obj_arg easy,
    uint32_t option,
    b_lean_obj_arg slist,
    lean_obj_arg world
) {
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy);
    SlistWrapper* slist_wrapper = (SlistWrapper*)lean_get_external_data(slist);

    CURLcode res = curl_easy_setopt(wrapper->handle, (CURLoption)option, slist_wrapper->list);
    if (res != CURLE_OK) {
        return mk_curl_error(res);
    }

    if (slist_wrapper->list) {
        if (wrapper->owned_slist) {
            curl_slist_free_all(wrapper->owned_slist);
        }
        wrapper->owned_slist = slist_wrapper->list;
        slist_wrapper->list = NULL;
    }

    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_obj_res wisp_easy_setopt_blob(
    b_lean_obj_arg easy,
    uint32_t option,
    b_lean_obj_arg data,
    size_t len,
    lean_obj_arg world
) {
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy);
    uint8_t* ptr = lean_sarray_cptr(data);

    struct curl_blob blob;
    blob.data = ptr;
    blob.len = len;
    blob.flags = CURL_BLOB_COPY;

    CURLcode res = curl_easy_setopt(wrapper->handle, (CURLoption)option, &blob);
    if (res != CURLE_OK) {
        return mk_curl_error(res);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_obj_res wisp_easy_setopt_mime(
    b_lean_obj_arg easy,
    b_lean_obj_arg mime,
    lean_obj_arg world
) {
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy);
    MimeWrapper* mime_wrapper = (MimeWrapper*)lean_get_external_data(mime);

    CURLcode res = curl_easy_setopt(wrapper->handle, CURLOPT_MIMEPOST, mime_wrapper->mime);
    if (res != CURLE_OK) {
        return mk_curl_error(res);
    }

    if (mime_wrapper->mime) {
        if (wrapper->owned_mime) {
            curl_mime_free(wrapper->owned_mime);
        }
        wrapper->owned_mime = mime_wrapper->mime;
        mime_wrapper->mime = NULL;
    }

    return lean_io_result_mk_ok(lean_box(0));
}

// ============================================================================
// Getinfo Operations
// ============================================================================

LEAN_EXPORT lean_obj_res wisp_easy_getinfo_long(
    b_lean_obj_arg easy,
    uint32_t info,
    lean_obj_arg world
) {
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy);
    long value = 0;

    CURLcode res = curl_easy_getinfo(wrapper->handle, (CURLINFO)info, &value);
    if (res != CURLE_OK) {
        return mk_curl_error(res);
    }

    return lean_io_result_mk_ok(lean_box_uint64((uint64_t)value));
}

LEAN_EXPORT lean_obj_res wisp_easy_getinfo_double(
    b_lean_obj_arg easy,
    uint32_t info,
    lean_obj_arg world
) {
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy);
    double value = 0.0;

    CURLcode res = curl_easy_getinfo(wrapper->handle, (CURLINFO)info, &value);
    if (res != CURLE_OK) {
        return mk_curl_error(res);
    }

    return lean_io_result_mk_ok(lean_box_float(value));
}

LEAN_EXPORT lean_obj_res wisp_easy_getinfo_string(
    b_lean_obj_arg easy,
    uint32_t info,
    lean_obj_arg world
) {
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy);
    char* value = NULL;

    CURLcode res = curl_easy_getinfo(wrapper->handle, (CURLINFO)info, &value);
    if (res != CURLE_OK) {
        return mk_curl_error(res);
    }

    return lean_io_result_mk_ok(lean_mk_string(value ? value : ""));
}

// ============================================================================
// Response Buffer Operations
// ============================================================================

LEAN_EXPORT lean_obj_res wisp_easy_setup_write_callback(b_lean_obj_arg easy, lean_obj_arg world) {
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy);

    curl_easy_setopt(wrapper->handle, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(wrapper->handle, CURLOPT_WRITEDATA, wrapper);

    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_obj_res wisp_easy_setup_header_callback(b_lean_obj_arg easy, lean_obj_arg world) {
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy);

    curl_easy_setopt(wrapper->handle, CURLOPT_HEADERFUNCTION, header_callback);
    curl_easy_setopt(wrapper->handle, CURLOPT_HEADERDATA, wrapper);

    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_obj_res wisp_easy_get_response_body(b_lean_obj_arg easy, lean_obj_arg world) {
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy);

    if (!wrapper->response_body || wrapper->response_size == 0) {
        lean_object* empty = lean_alloc_sarray(1, 0, 0);
        return lean_io_result_mk_ok(empty);
    }

    lean_object* arr = lean_alloc_sarray(1, wrapper->response_size, wrapper->response_size);
    memcpy(lean_sarray_cptr(arr), wrapper->response_body, wrapper->response_size);

    return lean_io_result_mk_ok(arr);
}

LEAN_EXPORT lean_obj_res wisp_easy_get_response_headers(b_lean_obj_arg easy, lean_obj_arg world) {
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy);

    if (!wrapper->response_headers || wrapper->headers_size == 0) {
        return lean_io_result_mk_ok(lean_mk_string(""));
    }

    return lean_io_result_mk_ok(lean_mk_string(wrapper->response_headers));
}

// ============================================================================
// Slist Operations
// ============================================================================

LEAN_EXPORT lean_obj_res wisp_slist_new(lean_obj_arg world) {
    if (!g_initialized) {
        lean_object* init_result = wisp_global_init(lean_box(0));
        lean_dec(init_result);
    }

    SlistWrapper* wrapper = calloc(1, sizeof(SlistWrapper));
    if (!wrapper) {
        return mk_io_error("Failed to allocate SlistWrapper");
    }

    lean_object* obj = lean_alloc_external(g_slist_class, wrapper);
    return lean_io_result_mk_ok(obj);
}

LEAN_EXPORT lean_obj_res wisp_slist_append(
    b_lean_obj_arg slist,
    b_lean_obj_arg str,
    lean_obj_arg world
) {
    SlistWrapper* wrapper = (SlistWrapper*)lean_get_external_data(slist);
    const char* s = lean_string_cstr(str);

    struct curl_slist* new_list = curl_slist_append(wrapper->list, s);
    if (!new_list && s[0] != '\0') {
        return mk_io_error("Failed to append to slist");
    }

    wrapper->list = new_list;
    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_obj_res wisp_slist_free(b_lean_obj_arg slist, lean_obj_arg world) {
    // Cleanup is handled by finalizer
    return lean_io_result_mk_ok(lean_box(0));
}

// ============================================================================
// Mime Operations
// ============================================================================

LEAN_EXPORT lean_obj_res wisp_mime_init(b_lean_obj_arg easy, lean_obj_arg world) {
    EasyWrapper* e_wrapper = (EasyWrapper*)lean_get_external_data(easy);

    curl_mime* mime = curl_mime_init(e_wrapper->handle);
    if (!mime) {
        return mk_io_error("Failed to create CURL mime handle");
    }

    MimeWrapper* wrapper = calloc(1, sizeof(MimeWrapper));
    if (!wrapper) {
        curl_mime_free(mime);
        return mk_io_error("Failed to allocate MimeWrapper");
    }
    wrapper->mime = mime;
    wrapper->easy = e_wrapper->handle;

    lean_object* obj = lean_alloc_external(g_mime_class, wrapper);
    return lean_io_result_mk_ok(obj);
}

LEAN_EXPORT lean_obj_res wisp_mime_addpart(b_lean_obj_arg mime, lean_obj_arg world) {
    MimeWrapper* m_wrapper = (MimeWrapper*)lean_get_external_data(mime);

    curl_mimepart* part = curl_mime_addpart(m_wrapper->mime);
    if (!part) {
        return mk_io_error("Failed to add mime part");
    }

    MimepartWrapper* wrapper = calloc(1, sizeof(MimepartWrapper));
    if (!wrapper) {
        return mk_io_error("Failed to allocate MimepartWrapper");
    }
    wrapper->part = part;

    lean_object* obj = lean_alloc_external(g_mimepart_class, wrapper);
    return lean_io_result_mk_ok(obj);
}

LEAN_EXPORT lean_obj_res wisp_mimepart_name(
    b_lean_obj_arg part,
    b_lean_obj_arg name,
    lean_obj_arg world
) {
    MimepartWrapper* wrapper = (MimepartWrapper*)lean_get_external_data(part);
    const char* n = lean_string_cstr(name);

    CURLcode res = curl_mime_name(wrapper->part, n);
    if (res != CURLE_OK) {
        return mk_curl_error(res);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_obj_res wisp_mimepart_data(
    b_lean_obj_arg part,
    b_lean_obj_arg data,
    lean_obj_arg world
) {
    MimepartWrapper* wrapper = (MimepartWrapper*)lean_get_external_data(part);
    size_t size = lean_sarray_size(data);
    uint8_t* ptr = lean_sarray_cptr(data);

    CURLcode res = curl_mime_data(wrapper->part, (const char*)ptr, size);
    if (res != CURLE_OK) {
        return mk_curl_error(res);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_obj_res wisp_mimepart_filename(
    b_lean_obj_arg part,
    b_lean_obj_arg filename,
    lean_obj_arg world
) {
    MimepartWrapper* wrapper = (MimepartWrapper*)lean_get_external_data(part);
    const char* f = lean_string_cstr(filename);

    CURLcode res = curl_mime_filename(wrapper->part, f);
    if (res != CURLE_OK) {
        return mk_curl_error(res);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_obj_res wisp_mimepart_type(
    b_lean_obj_arg part,
    b_lean_obj_arg mimetype,
    lean_obj_arg world
) {
    MimepartWrapper* wrapper = (MimepartWrapper*)lean_get_external_data(part);
    const char* t = lean_string_cstr(mimetype);

    CURLcode res = curl_mime_type(wrapper->part, t);
    if (res != CURLE_OK) {
        return mk_curl_error(res);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_obj_res wisp_mimepart_filedata(
    b_lean_obj_arg part,
    b_lean_obj_arg filepath,
    lean_obj_arg world
) {
    MimepartWrapper* wrapper = (MimepartWrapper*)lean_get_external_data(part);
    const char* f = lean_string_cstr(filepath);

    CURLcode res = curl_mime_filedata(wrapper->part, f);
    if (res != CURLE_OK) {
        return mk_curl_error(res);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_obj_res wisp_mime_free(b_lean_obj_arg mime, lean_obj_arg world) {
    // Cleanup is handled by finalizer
    return lean_io_result_mk_ok(lean_box(0));
}

// ============================================================================
// Multi Handle Operations
// ============================================================================

LEAN_EXPORT lean_obj_res wisp_multi_init(lean_obj_arg world) {
    if (!g_initialized) {
        lean_object* init_result = wisp_global_init(lean_box(0));
        lean_dec(init_result);
    }

    CURLM* handle = curl_multi_init();
    if (!handle) {
        return mk_io_error("Failed to create CURL multi handle");
    }

    // Configure connection caching for better performance
    // Increase max connections (default is 5, increase for tile loading scenarios)
    curl_multi_setopt(handle, CURLMOPT_MAXCONNECTS, 16L);

    // Enable HTTP/2 multiplexing if available
    curl_multi_setopt(handle, CURLMOPT_PIPELINING, CURLPIPE_MULTIPLEX);

    MultiWrapper* wrapper = calloc(1, sizeof(MultiWrapper));
    if (!wrapper) {
        curl_multi_cleanup(handle);
        return mk_io_error("Failed to allocate MultiWrapper");
    }
    wrapper->handle = handle;

    lean_object* obj = lean_alloc_external(g_multi_class, wrapper);
    return lean_io_result_mk_ok(obj);
}

LEAN_EXPORT lean_obj_res wisp_multi_cleanup(b_lean_obj_arg multi, lean_obj_arg world) {
    // Cleanup is handled by finalizer
    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_obj_res wisp_multi_add_handle(
    b_lean_obj_arg multi,
    b_lean_obj_arg easy,
    lean_obj_arg world
) {
    MultiWrapper* m_wrapper = (MultiWrapper*)lean_get_external_data(multi);
    EasyWrapper* e_wrapper = (EasyWrapper*)lean_get_external_data(easy);

    CURLMcode res = curl_multi_add_handle(m_wrapper->handle, e_wrapper->handle);
    if (res != CURLM_OK) {
        return mk_curlm_error(res);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_obj_res wisp_multi_remove_handle(
    b_lean_obj_arg multi,
    b_lean_obj_arg easy,
    lean_obj_arg world
) {
    MultiWrapper* m_wrapper = (MultiWrapper*)lean_get_external_data(multi);
    EasyWrapper* e_wrapper = (EasyWrapper*)lean_get_external_data(easy);

    CURLMcode res = curl_multi_remove_handle(m_wrapper->handle, e_wrapper->handle);
    if (res != CURLM_OK) {
        return mk_curlm_error(res);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_obj_res wisp_multi_perform(b_lean_obj_arg multi, lean_obj_arg world) {
    MultiWrapper* wrapper = (MultiWrapper*)lean_get_external_data(multi);
    int still_running = 0;

    CURLMcode res = curl_multi_perform(wrapper->handle, &still_running);
    if (res != CURLM_OK) {
        return mk_curlm_error(res);
    }

    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)still_running));
}

LEAN_EXPORT lean_obj_res wisp_multi_poll(
    b_lean_obj_arg multi,
    uint32_t timeout_ms,
    lean_obj_arg world
) {
    MultiWrapper* wrapper = (MultiWrapper*)lean_get_external_data(multi);
    int numfds = 0;

    CURLMcode res = curl_multi_poll(wrapper->handle, NULL, 0, (int)timeout_ms, &numfds);
    if (res != CURLM_OK) {
        return mk_curlm_error(res);
    }

    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)numfds));
}

LEAN_EXPORT lean_obj_res wisp_multi_info_read(b_lean_obj_arg multi, lean_obj_arg world) {
    MultiWrapper* wrapper = (MultiWrapper*)lean_get_external_data(multi);
    int msgs_in_queue = 0;

    while (1) {
        CURLMsg* msg = curl_multi_info_read(wrapper->handle, &msgs_in_queue);
        if (!msg) {
            return lean_io_result_mk_ok(lean_box(0));
        }
        if (msg->msg != CURLMSG_DONE) {
            continue;
        }

        void* private_ptr = NULL;
        curl_easy_getinfo(msg->easy_handle, CURLINFO_PRIVATE, &private_ptr);
        uint64_t id = (uint64_t)(uintptr_t)private_ptr;
        uint32_t code = (uint32_t)msg->data.result;

        lean_object* pair = lean_alloc_ctor(0, 2, 0);
        lean_ctor_set(pair, 0, lean_box_uint64(id));
        lean_ctor_set(pair, 1, lean_box_uint32(code));

        lean_object* some = lean_alloc_ctor(1, 1, 0);
        lean_ctor_set(some, 0, pair);

        return lean_io_result_mk_ok(some);
    }
}

// ============================================================================
// URL Encoding
// ============================================================================

LEAN_EXPORT lean_obj_res wisp_url_encode(
    b_lean_obj_arg easy,
    b_lean_obj_arg str,
    lean_obj_arg world
) {
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy);
    const char* s = lean_string_cstr(str);

    char* encoded = curl_easy_escape(wrapper->handle, s, 0);
    if (!encoded) {
        return mk_io_error("URL encoding failed");
    }

    lean_object* result = lean_mk_string(encoded);
    curl_free(encoded);

    return lean_io_result_mk_ok(result);
}

LEAN_EXPORT lean_obj_res wisp_url_decode(
    b_lean_obj_arg easy,
    b_lean_obj_arg str,
    lean_obj_arg world
) {
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy);
    const char* s = lean_string_cstr(str);
    int outlen = 0;

    char* decoded = curl_easy_unescape(wrapper->handle, s, 0, &outlen);
    if (!decoded) {
        return mk_io_error("URL decoding failed");
    }

    lean_object* result = lean_mk_string_from_bytes(decoded, outlen);
    curl_free(decoded);

    return lean_io_result_mk_ok(result);
}

// ============================================================================
// Streaming Support
// ============================================================================

LEAN_EXPORT lean_obj_res wisp_easy_set_streaming(
    b_lean_obj_arg easy,
    uint8_t streaming,
    lean_obj_arg world
) {
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy);
    wrapper->is_streaming = streaming ? 1 : 0;
    wrapper->stream_read_offset = 0;
    wrapper->headers_complete = 0;
    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_obj_res wisp_easy_is_streaming(
    b_lean_obj_arg easy,
    lean_obj_arg world
) {
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy);
    return lean_io_result_mk_ok(lean_box(wrapper->is_streaming ? 1 : 0));
}

LEAN_EXPORT lean_obj_res wisp_easy_headers_complete(
    b_lean_obj_arg easy,
    lean_obj_arg world
) {
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy);
    return lean_io_result_mk_ok(lean_box(wrapper->headers_complete ? 1 : 0));
}

// Get new body data since last drain (for streaming)
// Returns ByteArray of new bytes, updates read offset
LEAN_EXPORT lean_obj_res wisp_easy_drain_body_chunk(
    b_lean_obj_arg easy,
    lean_obj_arg world
) {
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy);

    size_t available = wrapper->response_size - wrapper->stream_read_offset;
    if (available == 0) {
        // No new data - return empty ByteArray
        lean_object* empty = lean_alloc_sarray(1, 0, 0);
        return lean_io_result_mk_ok(empty);
    }

    // Create ByteArray with new data
    lean_object* arr = lean_alloc_sarray(1, available, available);
    memcpy(lean_sarray_cptr(arr),
           wrapper->response_body + wrapper->stream_read_offset,
           available);

    // Update read offset
    wrapper->stream_read_offset = wrapper->response_size;

    return lean_io_result_mk_ok(arr);
}

// Check if there's pending body data to drain
LEAN_EXPORT lean_obj_res wisp_easy_has_pending_data(
    b_lean_obj_arg easy,
    lean_obj_arg world
) {
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy);
    size_t available = wrapper->response_size - wrapper->stream_read_offset;
    return lean_io_result_mk_ok(lean_box(available > 0 ? 1 : 0));
}

// Reset streaming state (for reuse)
LEAN_EXPORT lean_obj_res wisp_easy_reset_streaming(
    b_lean_obj_arg easy,
    lean_obj_arg world
) {
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy);
    wrapper->stream_read_offset = 0;
    wrapper->headers_complete = 0;
    return lean_io_result_mk_ok(lean_box(0));
}

// ============================================================================
// WebSocket Support (curl 7.86+)
// ============================================================================

// Check if WebSocket support is available in the linked libcurl at runtime
// Since curl 8.11+, WebSocket is enabled by default
LEAN_EXPORT lean_obj_res wisp_ws_check_support(lean_obj_arg world) {
#if LIBCURL_VERSION_NUM >= 0x075600  // 7.86.0 - first version with WebSocket API
    // Check runtime support via curl_version_info
    // The library linked at runtime may differ from compile time
    curl_version_info_data* info = curl_version_info(CURLVERSION_NOW);
    #ifdef CURL_VERSION_WEBSOCKETS
    int supported = (info->features & CURL_VERSION_WEBSOCKETS) != 0;
    #else
    // CURL_VERSION_WEBSOCKETS not defined at compile time, assume available
    // if we compiled against 7.86+ (the API exists even if flag is missing)
    int supported = 1;
    #endif
    return lean_io_result_mk_ok(lean_box(supported ? 1 : 0));
#else
    return lean_io_result_mk_ok(lean_box(0));
#endif
}

// Send a WebSocket frame
LEAN_EXPORT lean_obj_res wisp_ws_send(
    b_lean_obj_arg easy_obj,
    b_lean_obj_arg data,
    uint32_t frame_type,
    lean_obj_arg world
) {
#if LIBCURL_VERSION_NUM >= 0x075600  // 7.86.0
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy_obj);
    size_t len = lean_sarray_size(data);
    const char* buf = (const char*)lean_sarray_cptr(data);

    size_t sent;
    CURLcode res = curl_ws_send(wrapper->handle, buf, len, &sent, 0, frame_type);
    if (res != CURLE_OK) {
        return mk_curl_error(res);
    }
    return lean_io_result_mk_ok(lean_box(0));
#else
    return mk_io_error("WebSocket support not available in libcurl");
#endif
}

// Receive a WebSocket frame (returns Option (ByteArray × UInt32))
LEAN_EXPORT lean_obj_res wisp_ws_recv(b_lean_obj_arg easy_obj, lean_obj_arg world) {
#if LIBCURL_VERSION_NUM >= 0x075600  // 7.86.0
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy_obj);
    char buffer[65536];
    size_t received = 0;
    const struct curl_ws_frame* meta = NULL;

    CURLcode res = curl_ws_recv(wrapper->handle, buffer, sizeof(buffer), &received, &meta);
    if (res == CURLE_AGAIN) {
        // No data available - return None (constructor 0, no args)
        return lean_io_result_mk_ok(lean_box(0));  // Option.none
    }
    if (res != CURLE_OK) {
        return mk_curl_error(res);
    }

    // Build (ByteArray × UInt32) tuple
    lean_object* bytes = lean_alloc_sarray(1, received, received);
    memcpy(lean_sarray_cptr(bytes), buffer, received);

    // Get frame flags from metadata
    uint32_t flags = meta ? meta->flags : 0;

    lean_object* pair = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(pair, 0, bytes);
    lean_ctor_set(pair, 1, lean_box_uint32(flags));

    // Return Some(pair) - constructor 1 with 1 argument
    lean_object* some = lean_alloc_ctor(1, 1, 0);
    lean_ctor_set(some, 0, pair);
    return lean_io_result_mk_ok(some);
#else
    return mk_io_error("WebSocket support not available in libcurl");
#endif
}

// Get WebSocket metadata (offset, bytesleft, flags) after a recv call
LEAN_EXPORT lean_obj_res wisp_ws_meta(b_lean_obj_arg easy_obj, lean_obj_arg world) {
#if LIBCURL_VERSION_NUM >= 0x075600  // 7.86.0
    EasyWrapper* wrapper = (EasyWrapper*)lean_get_external_data(easy_obj);
    const struct curl_ws_frame* meta = curl_ws_meta(wrapper->handle);

    uint64_t offset = 0;
    uint64_t bytesleft = 0;
    uint32_t flags = 0;

    if (meta) {
        offset = meta->offset;
        bytesleft = meta->bytesleft;
        flags = meta->flags;
    }

    // Build (UInt64 × UInt64 × UInt32) tuple
    // This is Prod UInt64 (Prod UInt64 UInt32)
    lean_object* inner = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(inner, 0, lean_box_uint64(bytesleft));
    lean_ctor_set(inner, 1, lean_box_uint32(flags));

    lean_object* outer = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(outer, 0, lean_box_uint64(offset));
    lean_ctor_set(outer, 1, inner);

    return lean_io_result_mk_ok(outer);
#else
    return mk_io_error("WebSocket support not available in libcurl");
#endif
}
