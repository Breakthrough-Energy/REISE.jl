FROM python:3.8.3

WORKDIR /build/julia_installer

RUN wget -q https://julialang-s3.julialang.org/bin/linux/x64/1.4/julia-1.4.2-linux-x86_64.tar.gz &&\ 
    tar -xf julia-1.4.2-linux-x86_64.tar.gz -C /usr/share

WORKDIR /build/gurobi_installer

RUN wget -q https://packages.gurobi.com/9.0/gurobi9.0.2_linux64.tar.gz &&\
    mkdir /usr/share/gurobi902 &&\
    tar -xf gurobi9.0.2_linux64.tar.gz -C /usr/share

ENV PATH="$PATH:/usr/share/julia-1.4.2/bin" \
    LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/share/gurobi902/linux64/lib \
    GUROBI_HOME='/usr/share/gurobi902/linux64' \
    GRB_LICENSE_FILE='/usr/share/gurobi_license/gurobi.lic' \
    JULIA_PROJECT='/app' \
    PYTHONPATH=/app/pyreisejl:${PYTHONPATH}

WORKDIR /app
COPY . .

RUN julia -e 'using Pkg; Pkg.activate("."); Pkg.instantiate(), using REISE' &&\
    pip install -r requirements.txt




WORKDIR /app
ENTRYPOINT ["bash"]