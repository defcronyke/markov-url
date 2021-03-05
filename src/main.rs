#![feature(async_closure)]

use hyper::header::HeaderValue;
use hyper::server::conn::AddrStream;
use hyper::service::{make_service_fn, service_fn};
use hyper::{Body, Method, Request, Response, Server, StatusCode};
use std::collections::HashMap;
use std::convert::Infallible;
use std::env;
use std::net::SocketAddr;
use std::process::Command;

static NOTFOUND: &[u8] = b"404 Not Found";

fn get_ip(req: &Request<Body>, addr: &SocketAddr) -> String {
    let headers = req.headers();
    let default_header_value = HeaderValue::from_str("").unwrap();

    let x_forwarded_for = headers
        .get("x-forwarded-for")
        .unwrap_or(&default_header_value)
        .to_str()
        .unwrap_or_default();

    if x_forwarded_for != "" {
        format!("{} -> {}", x_forwarded_for, &addr.to_string())
    } else {
        format!("{}", &addr.to_string())
    }
}

async fn handle_root(req: Request<Body>, addr: SocketAddr) -> Result<Response<Body>, Infallible> {
    let params: HashMap<String, String> = req
        .uri()
        .query()
        .map(|v| {
            url::form_urlencoded::parse(v.as_bytes())
                .into_owned()
                .collect()
        })
        .unwrap_or_else(HashMap::new);

    let num_words_default_str = "50".to_string();
    let num_words_default: u64 = num_words_default_str.parse().unwrap();

    let num_words_max: u64 = 2000;

    let num_words_str = params.get("words").unwrap_or(&num_words_default_str);

    let num_words: u64 = num_words_str.parse().map_or_else(
        |_err| num_words_default,
        |res| {
            if res > num_words_max {
                num_words_max
            } else {
                res
            }
        },
    );

    let num_words_str = num_words.to_string();

    println!(
        "connection from: {}\nnum words: {}",
        &get_ip(&req, &addr),
        &num_words_str.clone()
    );

    let max_retries = 5;
    let retry_delay = 3;
    let mut first_try = true;
    let mut retry_num = 0;

    let mut out = "".to_string();

    while (retry_num < max_retries) && (out == "" || out == "\n") {
        let output = Command::new("./markov-url-online.sh")
            .arg(&num_words_str.clone())
            .output();

        if output.is_err() {
            return Ok(Response::new(Body::from(output.unwrap_err().to_string())));
        }

        let output = output.unwrap();

        let stderr = std::str::from_utf8(&output.stderr).unwrap();
        let stdout = std::str::from_utf8(&output.stdout).unwrap();

        out = format!("{}{}", stderr, stdout);

        if out == "" || out == "\n" {
            retry_num += 1;

            println!(
                "warning: No output. Trying again: ({}/{})",
                retry_num, max_retries
            );

            if !first_try {
                std::thread::sleep(std::time::Duration::from_millis(retry_delay * 1000))
            } else {
                first_try = false;
            }
        }
    }

    Ok(Response::new(Body::from(out)))
}

async fn handle_err_404_not_found(
    req: Request<Body>,
    addr: SocketAddr,
) -> Result<Response<Body>, Infallible> {
    println!("404 error connection from: {}", &get_ip(&req, &addr));

    Ok(Response::builder()
        .status(StatusCode::NOT_FOUND)
        .body(NOTFOUND.into())
        .unwrap())
}

#[tokio::main]
async fn main() {
    let port: u16 = env::var("PORT")
        .unwrap_or("3000".to_string())
        .parse()
        .unwrap();

    let addr = SocketAddr::from(([0, 0, 0, 0], port));

    let make_svc = make_service_fn(move |conn: &AddrStream| {
        let addr = conn.remote_addr();

        async move {
            // let addr = addr.clone();
            Ok::<_, Infallible>(service_fn(async move |req| {
                match (req.method(), req.uri().path()) {
                    (&Method::GET, "/") | (&Method::GET, "/index.html") => {
                        handle_root(req, addr.clone()).await
                    }

                    _ => handle_err_404_not_found(req, addr.clone()).await,
                }
            }))
        }
    });

    let server = Server::bind(&addr).serve(make_svc);

    println!("server listening: {}:{}", "http://localhost", port);

    if let Err(e) = server.await {
        eprintln!("server error: {}", e);
    }
}
