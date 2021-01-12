vcl 4.0;

# Based on: https://github.com/mattiasgeniar/varnish-4.0-configuration-templates/blob/master/default.vcl

import std;
import directors;

backend primary {
  .host = "$BACKEND_PRIMARY_HOST";
  .port = "$BACKEND_PRIMARY_PORT";
  .connect_timeout = 5s;
  .first_byte_timeout = 5s;
  .between_bytes_timeout = 2s;
}

backend secondary {
  .host = "$BACKEND_SECONDARY_HOST";
  .port = "$BACKEND_SECONDARY_PORT";
  .connect_timeout = 5s;
  .first_byte_timeout = 5s;
  .between_bytes_timeout = 2s;
}

acl purge {
  "localhost";
  "127.0.0.1";
  "::1";
}

sub vcl_init {
  new balancer = directors.round_robin();

  balancer.add_backend(primary);
  balancer.add_backend(secondary);
}

sub vcl_recv {

  // std.syslog(0, "RECEIVED");

  # Get a random backend from director
  set req.backend_hint = balancer.backend();

  if (std.healthy(req.backend_hint)) {
    // If backend is healthy, only set grace period of 10s
    // If backend is sick, grace period goes back at 1h
    set req.grace = 10s;
  }

  # Normalize the header, remove the port (in case you're testing this on various TCP ports)
  set req.url = std.querysort(req.url); # Normalize the query arguments
  set req.http.host = regsub(req.http.Host, ":[0-9]+", "");
  unset req.http.proxy; # Remove the proxy header (see https://httpoxy.org/#mitigate-varnish)
  unset req.http.cookie; # Ignore all cookies, because nobody cares

  # If only a OPTIONS request, respond and cache
  if (req.method == "OPTIONS") {
    return (synth(204));
  }

  if (req.method == "PURGE") {
    if (!client.ip ~ purge) { 
      # Not from an allowed IP? Then die with an error.
      return (synth(401, "No. Bye."));
    }

    return (purge);
  }

  # Only allow GET and HEAD requests
  if (req.method != "GET" && req.method != "HEAD") {
    return (synth(405, "Invalid method"));
  }

  return (hash);
}

sub vcl_pipe {
  set bereq.http.Connection = "Close";

  return (pipe);
}

# The data on which the hashing will take place
sub vcl_hash {
  hash_data(req.url);

  if (req.http.host) {
    hash_data(req.http.host);
  } else {
    hash_data(server.ip);
  }

  # No support for cookies since no request is supposed to have some
}

sub vcl_hit {
  # Called when a cache lookup is successful.

  if (obj.ttl >= 0s) {
    # A pure unadultered hit, deliver it
    return (deliver);
  }

  # fetch & deliver once we get the result
  return (miss); # Dead code, keep as a safeguard
}

sub vcl_backend_response {

  unset beresp.http.set-cookie; # Remove all cookies, nobody cares
  set beresp.do_stream = true; # Pass though without waiting for body
  set beresp.ttl = 1h; # Store for 1h by default

  if (bereq.url ~ "^[^?]*\.(m3u|m3u8)(\?.*)?$") {
    set beresp.ttl = 1s; # Set cache ttl as 1s for playlist
  }

  # Allow stale content for an hour, in case the backend goes down.
  set beresp.grace = 6h;

  return (deliver);
}

sub vcl_deliver {
  # Called before a cached object is delivered to the client.

  # Debug headers
  if (obj.hits > 0) { set resp.http.X-Cache = "HIT"; }
  else { set resp.http.X-Cache = "MISS"; }

  set resp.http.X-Cache-Hits = obj.hits;

  # Unset Varnish related headers
  unset resp.http.Via;
  unset resp.http.X-Varnish;
  unset resp.http.Server;

  # Set pretty header
  set resp.http.X-Powered-By = std.getenv("HEADER_POWERED_BY");

  # Fix all CORS on the fly
  set resp.http.Access-Control-Max-Age = "1728000";
  set resp.http.Access-Control-Allow-Origin = req.http.host;
  set resp.http.Access-Control-Allow-Methods = "GET, HEAD, OPTIONS";

  return (deliver);
}

sub vcl_purge {
  # Only handle actual PURGE HTTP methods, everything else is discarded
  if (req.method == "PURGE") {
    # restart request
    set req.http.X-Purge = "Yes";
    return (restart);
  }
}

sub vcl_synth {
  if (resp.status == 204) {
    set resp.http.Content-Length = "0";
    set resp.http.Content-Type = "text/plain charset=UTF-8";
    set resp.body = "";
  }

  return (deliver);
}