use clap::Parser;
use keeper::cli::{run, Cli};

fn main() -> std::process::ExitCode {
    let cli = Cli::parse();
    run(cli)
}
