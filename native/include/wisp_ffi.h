/*
 * Wisp FFI Header
 * C bindings for libcurl
 */

#ifndef WISP_FFI_H
#define WISP_FFI_H

#include <lean/lean.h>
#include <curl/curl.h>

// Initialization
LEAN_EXPORT lean_obj_res wisp_global_init(lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_global_cleanup(lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_version_info(lean_obj_arg world);

// Easy handle operations
LEAN_EXPORT lean_obj_res wisp_easy_init(lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_easy_cleanup(b_lean_obj_arg easy, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_easy_reset(b_lean_obj_arg easy, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_easy_perform(b_lean_obj_arg easy, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_easy_setopt_private(b_lean_obj_arg easy, uint64_t value, lean_obj_arg world);

// Setopt operations
LEAN_EXPORT lean_obj_res wisp_easy_setopt_string(b_lean_obj_arg easy, uint32_t option, b_lean_obj_arg value, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_easy_setopt_long(b_lean_obj_arg easy, uint32_t option, int64_t value, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_easy_setopt_slist(b_lean_obj_arg easy, uint32_t option, b_lean_obj_arg slist, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_easy_setopt_blob(b_lean_obj_arg easy, uint32_t option, b_lean_obj_arg data, size_t len, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_easy_setopt_mime(b_lean_obj_arg easy, b_lean_obj_arg mime, lean_obj_arg world);

// Getinfo operations
LEAN_EXPORT lean_obj_res wisp_easy_getinfo_long(b_lean_obj_arg easy, uint32_t info, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_easy_getinfo_double(b_lean_obj_arg easy, uint32_t info, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_easy_getinfo_string(b_lean_obj_arg easy, uint32_t info, lean_obj_arg world);

// Response buffer operations
LEAN_EXPORT lean_obj_res wisp_easy_setup_write_callback(b_lean_obj_arg easy, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_easy_setup_header_callback(b_lean_obj_arg easy, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_easy_get_response_body(b_lean_obj_arg easy, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_easy_get_response_headers(b_lean_obj_arg easy, lean_obj_arg world);

// Slist operations
LEAN_EXPORT lean_obj_res wisp_slist_new(lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_slist_append(b_lean_obj_arg slist, b_lean_obj_arg str, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_slist_free(b_lean_obj_arg slist, lean_obj_arg world);

// Mime operations (multipart form data)
LEAN_EXPORT lean_obj_res wisp_mime_init(b_lean_obj_arg easy, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_mime_addpart(b_lean_obj_arg mime, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_mimepart_name(b_lean_obj_arg part, b_lean_obj_arg name, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_mimepart_data(b_lean_obj_arg part, b_lean_obj_arg data, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_mimepart_filename(b_lean_obj_arg part, b_lean_obj_arg filename, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_mimepart_type(b_lean_obj_arg part, b_lean_obj_arg mimetype, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_mimepart_filedata(b_lean_obj_arg part, b_lean_obj_arg filepath, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_mime_free(b_lean_obj_arg mime, lean_obj_arg world);

// Multi handle operations
LEAN_EXPORT lean_obj_res wisp_multi_init(lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_multi_cleanup(b_lean_obj_arg multi, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_multi_add_handle(b_lean_obj_arg multi, b_lean_obj_arg easy, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_multi_remove_handle(b_lean_obj_arg multi, b_lean_obj_arg easy, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_multi_perform(b_lean_obj_arg multi, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_multi_poll(b_lean_obj_arg multi, uint32_t timeout_ms, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_multi_info_read(b_lean_obj_arg multi, lean_obj_arg world);

// URL encoding
LEAN_EXPORT lean_obj_res wisp_url_encode(b_lean_obj_arg easy, b_lean_obj_arg str, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_url_decode(b_lean_obj_arg easy, b_lean_obj_arg str, lean_obj_arg world);

// Streaming support
LEAN_EXPORT lean_obj_res wisp_easy_set_streaming(b_lean_obj_arg easy, uint8_t streaming, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_easy_is_streaming(b_lean_obj_arg easy, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_easy_headers_complete(b_lean_obj_arg easy, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_easy_drain_body_chunk(b_lean_obj_arg easy, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_easy_has_pending_data(b_lean_obj_arg easy, lean_obj_arg world);
LEAN_EXPORT lean_obj_res wisp_easy_reset_streaming(b_lean_obj_arg easy, lean_obj_arg world);

#endif // WISP_FFI_H
