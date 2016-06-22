require "resty.core"
encode = require("cjson").encode
decode = require("cjson").decode
sha512 = require "resty.sha512"
str = require "resty.string"
random = require "resty.random"
lbs = require "lbs"

ffi = require("ffi")
ffi.cdef[[
    typedef long time_t;

    typedef struct timeval {
        time_t tv_sec;
        time_t tv_usec;
    } timeval;

    int gettimeofday(struct timeval* t, void* tzp);
]]
