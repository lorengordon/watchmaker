FROM public.ecr.aws/docker/library/almalinux:8@sha256:302c22dbd67f69ab14a432100acc81cbfe73f8bf8fee66ac62b563aa81709ca1

ARG USER=wam-builder
ARG USER_UID
ARG USER_GID

ENV PYTHON=python3.12

USER root

RUN if [[ ${USER_UID} -eq 0 ]] ; then adduser ${USER} ; \
    else if ! getent group "$USER_GID" ; then groupadd --gid ${USER_GID} ${USER} ; \
    else GROUP_NAME=$(getent group $USER_GID | awk -F':' '{print $1}') ; groupmod -n ${USER} "$GROUP_NAME" ; fi \
    && adduser --uid ${USER_UID} --gid ${USER_GID} ${USER} ; fi

COPY --chown=${USER}:${USER} requirements/pip.txt /requirements/pip.txt
COPY --chown=${USER}:${USER} requirements/basics.txt /requirements/basics.txt

RUN dnf install -y ${PYTHON}

RUN ${PYTHON} -m ensurepip --upgrade --default-pip \
    && ${PYTHON} -m pip install -r /requirements/pip.txt \
    && ${PYTHON} -m pip --version \
    && ${PYTHON} -m pip install -r /requirements/basics.txt \
    && ${PYTHON} -m pip list

RUN dnf -y install epel-release \
    && dnf -y install jq

USER ${USER}

ENV HOME="/home/${USER}"
