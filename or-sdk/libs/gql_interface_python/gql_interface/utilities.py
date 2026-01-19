import re


def check_endpoint(endpoint, prefix):
    """Check that the endpoint matches with the supplied prefix, and can be a vaild address or localhost address."""
    address_exp = re.search(
        rf"^{prefix}s?:\/\/[0-9]+.[0-9]+.[0-9]+.[0-9]+:[0-9]+$",
        endpoint,
        re.IGNORECASE)

    localhost_exp = re.search(rf"^{prefix}s?:\/\/localhost:[0-9]+$",
                              endpoint,
                              re.IGNORECASE)
    valid_endpoint = address_exp or localhost_exp
    if not valid_endpoint:
        raise Exception(
            f"{endpoint} does not match the required pattern ({prefix}(s)://0.0.0.0:XXXX or localhost equivalent)")
    return

