FROM python:3.8.3

WORKDIR /build/julia_installer

RUN wget -q https://julialang-s3.julialang.org/bin/linux/x64/1.5/julia-1.5.3-linux-x86_64.tar.gz &&\
    tar -xf julia-1.5.3-linux-x86_64.tar.gz -C /usr/share

WORKDIR /build/gurobi_installer

RUN wget -q https://packages.gurobi.com/9.1/gurobi9.1.0_linux64.tar.gz && \
    tar -xf gurobi9.1.0_linux64.tar.gz -C /usr/share

ENV PATH="$PATH:/usr/share/julia-1.5.3/bin" \
    LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/share/gurobi910/linux64/lib \
    GUROBI_HOME='/usr/share/gurobi910/linux64' \
    GRB_LICENSE_FILE='/usr/share/gurobi_license/gurobi.lic' \
    JULIA_PROJECT='/app' \
    PYTHONPATH=/app/pyreisejl:${PYTHONPATH} \
    FLASK_APP=pyreisejl/utility/app.py

WORKDIR /app
COPY requirements.txt .
RUN pip install -U pip; pip install -r requirements.txt

COPY Project.toml .
COPY Manifest.toml .
RUN mkdir src && touch src/REISE.jl

RUN julia -e 'using Pkg; \
	Pkg.activate("."); \
	Pkg.instantiate(); \
	Pkg.add("GLPK"); \
	Pkg.add("Gurobi"); \
	Pkg.add("Clp")'

COPY src src

RUN julia -e 'import Gurobi; \
	import Clp; \
	import GLPK; \
	using REISE'

COPY pyreisejl pyreisejl

CMD ["flask", "run", "--host", "0.0.0.0"]
