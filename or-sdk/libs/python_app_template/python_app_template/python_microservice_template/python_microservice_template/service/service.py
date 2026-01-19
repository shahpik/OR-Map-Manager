#
# ###############################################################################################
#
# This software is part of Deloitte’s Optimal Reality Digital Twin.
# Copyright (C) 2020, Deloitte Australia. All rights reserved.
# Created Date: 30/06/2020
# Technical Authority: Caleb Sawade
# Engagement Owner: Sean McClowry smcclowry@deloitte.com.au
#                   and Kellie Nuttall knuttall@deloitte.com.au
#
# ###############################################################################################
#
# Copyright (C) 2020, Deloitte Digital. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
import os
import requests
from aiohttp import web
import aiohttp_cors

from em_interface.connect import connect
from em_interface.configurations import save_configuration

from python_microservice_template.utilities import log_utils

global APP_PORT, APP_ADDRESS, EXPERIMENT_MANAGER_ENDPOINT, EXPERIMENT_MANAGER_WS_ENDPOINT
logger = log_utils.get_logger(__name__)
debug = False


def init_experiment_manager():
    try:
        global APP_PORT, APP_ADDRESS, EXPERIMENT_MANAGER_ENDPOINT, EXPERIMENT_MANAGER_WS_ENDPOINT
        APP_PORT = os.getenv("APP_PORT", "5082")
        APP_ADDRESS = os.getenv("APP_ADDRESS", "0.0.0.0")
        EXPERIMENT_MANAGER_ENDPOINT = os.getenv(
            "EXPERIMENT_MANAGER_ENDPOINT",
            "https://graphql-nonprod.optimalreality.com.au/graphql"  # TODO: configure this item
        )
        EXPERIMENT_MANAGER_WS_ENDPOINT = os.getenv(
            "EXPERIMENT_MANAGER_WS_ENDPOINT",
            "wss://graphql-nonprod.optimalreality.com.au/graphql"  # TODO: configure this item
        )
        token = os.getenv(
            "OR_MASTER_JWT",
            "06ef51e77eb04ff6a30a6d831aab1d81"  # TODO: configure this item
        )
        connect(
            EXPERIMENT_MANAGER_ENDPOINT,
            EXPERIMENT_MANAGER_WS_ENDPOINT, token=token
        )
    except Exception as err:
        logger.warning(
            f"Full introspection failed, check Experiment Manager is live. \n "
            f"Error:{err}")


async def handle_root(_):
    """
    Landing page.

    Returns
    -------
    message: Response
        Message for landing page.

    """
    return web.Response(
        text='Welcome to the python_microservice_template service',
        content_type="text/html"
    )


async def live(req):
    """Liveness check for container."""
    logger.debug(req)
    return web.Response(
        status=200,
        body="OK",
        content_type="text/html"
    )


async def complete(req):
    """Init complete check for container."""
    logger.debug(req)
    return web.Response(
        status=200,
        body="OK",
        content_type="text/html"
    )


async def ready(req):
    """Check required services are available."""
    logger.debug(req)
    global EXPERIMENT_MANAGER_ENDPOINT
    try:
        request = requests.get(EXPERIMENT_MANAGER_ENDPOINT)
    except ConnectionError:
        return web.Response(status=503, content_type="text/html")
    if request.status_code == 200:
        return web.Response(
            status=200,
            body="READY",
            content_type="text/html"
        )
    return web.Response(
        status=request.status_code,
        content_type="text/html",
        body="Ping to Experiment Manager Failed - server is disconnected"
    )


def init_routes(app, cors):
    """
    Initialises routes for app.

    Parameters
    ----------
    app:
        web application
    cors:
        cross origin support

    Returns
    -------
        app updated

    """
    logger.info(f"cross origin not handled yet: {cors}")
    app.router.add_get("/", handle_root)
    app.router.add_get('/ready', ready)
    app.router.add_get('/live', live)
    app.router.add_get('/init_complete', complete)


def _on_shutdown(app):
    pass


async def app() -> web.Application:
    logger = log_utils.get_logger(__name__)
    global APP_PORT, APP_ADDRESS, EXPERIMENT_MANAGER_ENDPOINT, EXPERIMENT_MANAGER_WS_ENDPOINT
    logger.info("Initialising the experiment manager connection using the EM Interface.")
    init_experiment_manager()
    logger.info("Creating web app client.")
    app = web.Application(client_max_size=1024**20)
    cors = aiohttp_cors.setup(app)
    init_routes(app, cors)
    app.on_shutdown.append(_on_shutdown)
    return app


if __name__ == '__main__':
    if debug:
        app = app()
        web.run_app(app, port=5082)
