import os
import typer
import toml
from enum import Enum
from ansible_vault import Vault

current_dir = os.path.dirname(os.path.realpath(__file__))
vault = Vault(os.environ["VAULT_PASSWORD"])

cmd = typer.Typer()


class Environment(Enum):
    STAGING = "staging"
    PROD = "prod"


def filter_keys(o: dict):
    unwanted_keys = [
        "POSTGRESQL_URL",
        "VECTOR_POSTGRESQL_URL",
        "AUTH0_SECRET",
        "AUTH0_BASE_URL",
        "ADMIN_EMAIL",
        "SPOTFLOW_STORAGE_BUCKET",
        "SPOTFLOW_PUBLIC_STORAGE_BUCKET",
        "BUCKET_CLIENT",
        "BACKEND_URL",
        "FRONTEND_URL",
        "QUESTDB_CONNECTION_STRING",
    ]
    return {k: v for k, v in o.items() if k not in unwanted_keys}


def get_vault_file(file_path: str):
    with open(file_path, "r") as f:
        data = vault.load_raw(f.read())
        o = toml.loads(data.decode("utf-8"))
        return filter_keys(o)


@cmd.command()
def tfvars(environment: Environment = Environment.STAGING.value):  # type: ignore
    secrets_file = os.path.join(
        current_dir, f"../../envs/{environment.value}/secrets.toml.enc"
    )
    internal_file = os.path.join(
        current_dir, f"../../envs/{environment.value}/internal.toml.enc"
    )
    google_projects = {
        Environment.STAGING: "spotflow-dev-417519",
        Environment.PROD: "spotflow-prod",
    }
    questdb_ips = {
        Environment.STAGING: "10.0.80.236",
        Environment.PROD: "10.0.80.236",  # Same instance?
    }

    main_file = os.path.join(current_dir, f"../../envs/{environment.value}/env.toml")
    out_file = os.path.join(current_dir, f"./{environment.value}.tfvars")
    secrets_data = get_vault_file(secrets_file)
    internal_data = get_vault_file(internal_file)
    main_data = filter_keys(toml.load(main_file))
    domain = f"{environment.value}.aws.getspot.io"
    total_data = {
        "ADMIN_EMAIL": "david@noxus.ai",
        "AUTH0_BASE_URL": f"https://{domain}",
        "BUCKET_CLIENT": "s3",
        "FRONTEND_URL": f"https://{domain}",
        "QUESTDB_CONNECTION_STRING": f"http::addr={questdb_ips[environment]}:9000;username=admin;password=quest;",
        **secrets_data,
        **internal_data,
        **main_data,
    }

    default_keys = {
        "project_name": "noxus",
        "environment": environment.value,
        "domain": domain,
        "dns_zone": f"aws.getspot.io",
        "google_project_id": google_projects[environment],
    }

    with open(out_file, "w") as f:
        for k, v in {**default_keys}.items():
            f.write(f'{k} = "{v}"\n')
        f.write("vm_config = {\n")
        for i, (k, v) in enumerate(sorted(total_data.items(), key=lambda x: x[0])):
            f.write(f'    {k} = "{v}"')
            if i != len(total_data) - 1:
                f.write(f",")
            f.write(f"\n")

        f.write("}\n")


if __name__ == "__main__":
    cmd()
