# Copyright 2019 Piers Harding.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM busybox

WORKDIR /root

ENV VENDOR "piersharding"
ENV DRIVER "imagevol"

# TODO Change to your desired driver.
COPY ./imagevol /imagevol

COPY deploy.sh /deploy.sh

CMD /bin/sh /deploy.sh
