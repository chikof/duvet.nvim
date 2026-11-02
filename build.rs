fn main() {
    println!("cargo:rerun-if-env-changed=DUVET_VERSION");
    println!("cargo:rerun-if-changed=.github/server-metadata.txt");

    let version = std::env::var("DUVET_VERSION").unwrap_or_else(|_| {
        let content = std::fs::read_to_string(".github/server-metadata.txt")
            .expect("server-metadata.txt not found");
        content
            .split('|')
            .next()
            .unwrap_or(&content)
            .trim()
            .to_string()
    });
    println!("cargo:rustc-env=DUVET_VERSION={}", version);
}
