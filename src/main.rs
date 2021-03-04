use hyper::service::{make_service_fn, service_fn};
use hyper::{Body, Request, Response, Server};
use std::convert::Infallible;
use std::env;
use std::net::SocketAddr;
use std::process::Command;

async fn handle_root(_req: Request<Body>) -> Result<Response<Body>, Infallible> {
    let output = Command::new("./markov-url-tmp.sh").arg("50").output();

    if output.is_err() {
        return Ok(Response::new(Body::from(output.unwrap_err().to_string())));
    }

    let output = output.unwrap();

    let stderr = std::str::from_utf8(&output.stderr).unwrap();
    let stdout = std::str::from_utf8(&output.stdout).unwrap();

    let out = format!("{}{}", stderr, stdout);

    Ok(Response::new(Body::from(out)))
}

#[tokio::main]
async fn main() {
    let _output = Command::new("/usr/bin/wget")
        .arg("https://tinyurl.com/markov-url")
        .arg("-O")
        .arg("markov-url-tmp.sh")
        .output()
        .unwrap();

    let _output = Command::new("/bin/chmod")
        .arg("755")
        .arg("markov-url-tmp.sh")
        .output()
        .unwrap();

    let port: u16 = env::var("PORT")
        .unwrap_or("3000".to_string())
        .parse()
        .unwrap();

    let addr = SocketAddr::from(([0, 0, 0, 0], port));

    let make_svc = make_service_fn(|_conn| async { Ok::<_, Infallible>(service_fn(handle_root)) });

    let server = Server::bind(&addr).serve(make_svc);

    if let Err(e) = server.await {
        eprintln!("server error: {}", e);
    }
}
