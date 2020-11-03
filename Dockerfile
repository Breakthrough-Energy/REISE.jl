FROM python:3.8.3

RUN mkdir -p /build/julia_installer
WORKDIR /build/julia_installer

RUN wget -q https://julialang-s3.julialang.org/bin/linux/x64/1.4/julia-1.4.2-linux-x86_64.tar.gz
RUN tar -xf julia-1.4.2-linux-x86_64.tar.gz -C /usr/share
ENV PATH="$PATH:/usr/share/julia-1.4.2/bin"

RUN mkdir /build/gurobi_installer
WORKDIR /build/gurobi_installer

RUN wget -q https://packages.gurobi.com/9.0/gurobi9.0.2_linux64.tar.gz
RUN mkdir /usr/share/gurobi902
RUN tar -xf gurobi9.0.2_linux64.tar.gz -C /usr/share

ENV LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/share/gurobi902/linux64/lib
ENV GUROBI_HOME='/usr/share/gurobi902/linux64'
ENV GRB_LICENSE_FILE='/usr/share/gurobi_license/gurobi.lic'
ENV JULIA_PROJECT='/app'

WORKDIR /app
COPY . .

RUN julia -e 'using Pkg; Pkg.activate("."); Pkg.instantiate(), using REISE'
RUN pip install -r requirements.txt


ENV FLASK_APP=pyreisejl/utility/app.py
ENV FLASK_ENV=development
ENV PYTHONPATH=/app/pyreisejl:${PYTHONPATH}

WORKDIR /app
ENTRYPOINT ["bash"]