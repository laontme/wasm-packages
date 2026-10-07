//! WASI multicall entry point for upstream's supported filesystem utilities.
use std::path::Path;
fn main() {
    let mut args: Vec<String> = std::env::args().collect();
    let invoked = Path::new(&args[0]).file_stem().unwrap_or_default().to_string_lossy().into_owned();
    if invoked == "findutils" {
        if args.get(1).map(String::as_str) == Some("--list") {
            println!("find\nlocate\nupdatedb");
            return;
        }
        if args.len() < 2 {
            eprintln!("usage: findutils <find|locate|updatedb> [arguments...]");
            std::process::exit(2);
        }
        args.remove(0);
    } else {
        args[0] = invoked;
    }
    let argv: Vec<&str> = args.iter().map(String::as_str).collect();
    let status = match argv[0] {
        "find" => findutils::find::find_main(&argv, &findutils::find::StandardDependencies::new()),
        "locate" => findutils::locate::locate_main(&argv),
        "updatedb" => findutils::updatedb::updatedb_main(&argv),
        _ => { eprintln!("findutils: unsupported command {:?}; xargs requires subprocess support", argv[0]); 2 }
    };
    std::process::exit(status);
}
