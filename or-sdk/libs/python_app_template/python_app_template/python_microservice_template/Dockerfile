##
## ###############################################################################################
##
## This software is part of Deloitte’s Optimal Reality Digital Twin.
## Copyright (C) 2020, Deloitte Australia. All rights reserved.
## Created Date: 30/06/2020
## Technical Authority: Caleb Sawade
## Engagement Owner: Sean McClowry smcclowry@deloitte.com.au
##                   and Kellie Nuttall knuttall@deloitte.com.au
##
## ###############################################################################################
##
## Copyright (C) 2020, Deloitte Digital. All rights reserved.
##
## Redistribution and use in source and binary forms, with or without
## modification, are permitted provided that the following conditions are met:
##
## * Redistributions of source code must retain the above copyright notice, this
## list of conditions and the following disclaimer.
##
## * Redistributions in binary form must reproduce the above copyright notice,
## this list of conditions and the following disclaimer in the documentation
## and/or other materials provided with the distribution.
##
## * Neither the name of the copyright holder nor the names of its contributors
## may be used to endorse or promote products derived from this software without
## specific prior written permission.
##
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
## AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
## IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
## DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
## FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
## DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
## SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
## CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
## OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
## OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
##
FROM python:3.8

# Set the working directory to /app
WORKDIR /app
COPY . .
ENV PYTHONPATH "${PYTHONPATH}:/app"
# Install the requirements
RUN apt-get update -y && \
    apt-get install netcat -y && \
    python3 -m pip install --no-cache-dir --upgrade pip && \
    python3 -m pip install --no-cache-dir -r requirements.txt && \
    cp pip.conf /etc/pip.conf && \
    python3 -m pip install -r requirements-libs.txt && \
    rm -f requirements-libs.txt; \
    rm pip.conf /etc/pip.conf && \
    rm -f requirements.txt && \
    apt-get clean -y && \
    rm -rf /var/{cache,lib,log}/apt &&\
    chmod 0755 /app/docker-entrypoint.sh

# Install the entrypoint
ENTRYPOINT ["/app/docker-entrypoint.sh"]

# Define the container port
EXPOSE 5082

# Define the command
CMD ["python_microservice_template.service.service:app", "--bind=:5082", "--worker-class=aiohttp.worker.GunicornWebWorker", "--workers=1", "--timeout=2000"]
