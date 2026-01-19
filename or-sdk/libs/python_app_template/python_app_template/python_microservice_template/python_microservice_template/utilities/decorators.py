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
"""
List of all general purpose decorators.
"""

from functools import wraps
from logging import Logger
import time


def run_once(f):
    """
    Runs a function (successfully) only once.

    The running can be reset by setting the `has_run` attribute to False.
    """

    @wraps(f)
    def wrapper(*args, **kwargs):
        if not wrapper.has_run:
            result = f(*args, **kwargs)
            wrapper.has_run = True
            wrapper.result = result
            return result
        return wrapper.result

    wrapper.has_run = False
    wrapper.result = None
    return wrapper


def log_time(logger: Logger):
    """
    Logs the computation time of a function at the DEBUG level.

    Will only log if root level is set to DEBUG.

    Parameters
    ----------
    logger : logging.Logger
        Logger object.

    """
    def _log_time(func):
        @wraps(func)
        def wrapper_timer(*args, **kwargs):
            if logger.root.level == 10:  # only log if level is set to DEBUG
                start_time = time.perf_counter()
                value = func(*args, **kwargs)
                logger.debug(f"Finished {func.__name__!r} in "
                             f"{time.perf_counter() - start_time:.4f} secs")
                return value
            else:
                return func(*args, **kwargs)
        return wrapper_timer
    return _log_time


def check_input_is_valid_text(func):
    """
    Confirm input format for a query is correct for experiment manager queries.

    Parameters
    ----------
    func:
        wrapped function

    Raises
    ------
    TypeException:
        if format of input argument is not text
    ValueException:
        for characters that aren't supported

    """
    @wraps(func)
    def confirm_format(*args, **kwargs):

        # characters not supported in graphql query
        bad_chars = ["\\", "'", "\""]
        allvals = list(args)
        allvals.extend(val for val in kwargs.values())
        for input_value in allvals:
            # check type
            if not isinstance(input_value, str):
                raise TypeError("Inputs to queries should be strings")

            # check included text
            if any([x in input_value for x in bad_chars]):
                raise ValueError(f"Characters not handled in query inputs: {bad_chars}")

        return func(*args, **kwargs)

    return confirm_format

