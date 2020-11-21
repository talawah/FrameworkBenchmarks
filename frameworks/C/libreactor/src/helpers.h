#ifndef HELPERS_H_INCLUDED
#define HELPERS_H_INCLUDED

segment http_date_header(int update);

segment http_content_length_header(uint32_t n);

void write_response(stream *stream, segment preamble, segment body);

void plaintext(server_context *context, char *response);

void json(server_context *context, clo *json_object);

#endif /* HELPERS_H_INCLUDED */
