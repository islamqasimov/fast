import requests
from datetime import datetime
from talon.fetchers.registry import register

AUTH_KEY = ""

@register("urlhaus")
def fetch_urlhaus():
    """Fetch recent malicious URLs from URLhaus API."""
    print("    -> Fetching from URLhaus API...")

    headers = {
        "Auth-Key": AUTH_KEY
    }

    try:
        response = requests.get(
            "https://urlhaus-api.abuse.ch/v1/urls/recent/",
            headers=headers,
            timeout=10
        )
        response.raise_for_status()
        data = response.json()

        if data.get("query_status") != "ok":
            print(f"    -> URLhaus API error: {data.get('query_status')}")
            return []

        results = []
        for entry in data.get("urls", []):
            raw_date = entry.get("date_added", "2026-01-01 00:00:00 UTC")
            
            # Remove trailing " UTC" and parse
            if raw_date.endswith(" UTC"):
                raw_date = raw_date[:-4]  # strip " UTC"
            try:
                dt = datetime.strptime(raw_date, "%Y-%m-%d %H:%M:%S")
                iso_date = dt.isoformat() + "Z"  # UTC timezone indicator
            except ValueError:
                # Fallback: keep original string as-is (but it might break later)
                iso_date = raw_date

            results.append({
                "type": "url",
                "value": entry.get("url", ""),
                "source": "urlhaus",
                "confidence": 50,
                "first_seen": iso_date,
                "last_seen": iso_date,
                "tags": ["malware", "urlhaus", entry.get("threat", "unknown")]
            })

        print(f"    -> Fetched {len(results)} URLs.")
        return results

    except requests.exceptions.RequestException as e:
        print(f"    -> URLhaus request error: {e}")
        return []
