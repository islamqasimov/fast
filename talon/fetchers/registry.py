from typing import Dict, Callable

FETCHERS: Dict[str, Callable] = {}

def register(name: str):
    """Decorator: Adds the fetcher function to the FETCHERS dictionary."""
    def decorator(func):
        FETCHERS[name] = func
        return func
    return decorator
