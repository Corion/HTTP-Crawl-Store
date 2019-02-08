create table response (
    retrieved                     timestamp not null,
    method                        varchar(6) not null,
    scheme                        varchar(6) not null,
    host                          varchar(128) not null,
    port                          decimal(5,0),
    path                          varchar(1024) not null,
    url                           varchar(2048) not null,
    status                        decimal(3,0),
    message                       varchar(80),
    header_content_type           varchar(80),
    header_etag                   varchar(80),
    header_date                   varchar(80),
    header_server                 varchar(80),
    header_content_disposition    varchar(80),
    header_content_length         varchar(80),
    header_cache_control          varchar(80),
    header_content_encoding       varchar(80),
    header_content_language       varchar(80),
    header_content_location       varchar(80),
    header_expires                varchar(80),
    header_set_cookie             varchar(80),
    header_transfer_encoding      varchar(80),
    header_x_powered_by           varchar(80),
    header_all                    varchar(8192), -- json array of headers
    response_digest               varchar(32)
);

create table http_body (
    digest varchar(32) unique not null
  , content blob
);

