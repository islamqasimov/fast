import argparse
from talon.pipeline import run_pipeline

def main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    run_parser = subparsers.add_parser("run")
    run_parser.add_argument("--mode", choices=["offline", "online", "diff"], default="offline")
    
    args = parser.parse_args()
    if args.command == "run":
        run_pipeline(mode=args.mode)

if __name__ == "__main__":
    main()
