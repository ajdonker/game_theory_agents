from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = PROJECT / "config" / "default.properties"
AGENT_COUNT = 8


def load_config(path=DEFAULT_CONFIG):
    """Read simple key=value properties files."""
    properties = {}

    for line in Path(path).read_text().splitlines():
        line = line.strip()
        if not line or line.startswith(("#", "!")):
            continue

        key, separator, value = line.partition("=")
        if not separator:
            raise ValueError(f"Invalid property: {line}")

        properties[key.strip()] = value.strip()

    return properties


def economic_values(config):
    endowment = float(config["game.endowment"])
    w = float(config["game.market1Return"])
    a = float(config["game.cprA"])
    b = float(config["game.cprB"])
    n = AGENT_COUNT

    if b <= 0 or endowment <= 0:
        raise ValueError("Invalid CPR parameters")

    capacity = n * endowment

    optimum = max(
        0.0,
        min(capacity, (a - w) / (2 * b))
    )

    nash = max(
        0.0,
        min(capacity, n * (a - w) / (b * (n + 1)))
    )

    tolerance = float(
        config["planner.optimalTolerance"]
    )
    max_group_rent = max(0.0, optimum * (a - w - b * optimum))

    return {
        "agent_count": n,
        "endowment": endowment,
        "market1_return": w,
        "cpr_a": a,
        "cpr_b": b,
        "optimum": optimum,
        "nash": nash,
        "optimal_band": tolerance * optimum,
        "max_group_investment": capacity,
        "max_group_rent": max_group_rent,
        "per_agent_optimum": optimum / n,
    }
