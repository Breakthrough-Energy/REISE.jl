Installation
------------
There are two options, either install all the dependencies yourself or setup the engine
within a Docker image. Whatever option you choose, you will need an external solver to
run optimizations. We recommend `Gurobi`_, though any other solver compatible with
`JuMP`_ can be used. Note that `Gurobi`_ is a commercial solver and hence a license
file is required. This may be either a local license, a cloud license or a free license
for academic use. Check their `Software Downloads and License Center
<https://www.python.org/dev/peps/pep-0257/>`_ page for more details.

Start by cloning the repository locally:

.. code-block:: bash

   git clone https://github.com/Breakthrough-Energy/REISE.jl

You will also need to download some input data in order to run simulations. Sample
data are available on `Zenodo`_. You will find there hourly time series for the
hydro/solar/wind generators and a MAT-file enclosing all the information related to the
electrical grid in accordance with the `MATPOWER`_ case file format.


Native Installation
+++++++++++++++++++
Installation will depend on your operating system. Some examples are provided for
Unix-like platforms.

Julia
#####
Download Julia 1.5 and install it following the instructions located on their
`Platform Specific Instructions for Official Binaries
<https://julialang.org/downloads/platform/>`_ page. This should be straightforward:

- Choose a destination directory. For shared installation, :bash:`/opt` is recommended.

  .. code-block:: bash

     cd /opt

- Download and unzip the package in the chosen directory:

  .. code-block:: bash

     wget -q https://julialang-s3.julialang.org/bin/linux/x64/1.5/julia-1.5.3-linux-x86_64.tar.gz
     tar -xf julia-1.5.3-linux-x86_64.tar.gz

- Expand the :bash:`PATH` environment variable. For bash users edit the **.bashrc**
  file in your :bash:`$HOME` folder:

  .. code-block:: bash

     export PATH="$PATH:/opt/julia-1.5.3/bin"


Gurobi
#######
If you plan on using `Gurobi`_ as a solver, you will need to download and install it
first so it can be accessed by `Jump`_. Installation of Gurobi depends on both the
operating system and the license type. Detailed instructions can be found in the
`Gurobi Installation Guide <https://www.gurobi.com/documentation/quickstart.html>`_.
For Unix-like platforms, this will look like:

- Choose a destination directory. For shared installation, :bash:`/opt` is recommended.

  .. code-block:: bash

     cd /opt

- Download and unzip the package in the chosen directory:

  .. code-block:: bash

     wget https://packages.gurobi.com/9.1/gurobi9.1.0_linux64.tar.gz
     tar -xvfz gurobi9.1.0_linux64.tar.gz

  This will create the :bash:`/opt/gurobi910/linux64` subdirectory in which the
  complete distribution is located.

- Set environments variables. For bash users edit the **.bashrc** file in your
  :bash:`$HOME` folder:

  .. code-block:: bash

     export GUROBI_HOME="/opt/gurobi910/linux64"
     export PATH="${PATH}:${GUROBI_HOME}/bin"
     export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${GUROBI_HOME}/lib"

- The Gurobi license needs to be download and installed. Download a copy of your Gurobi
  license from the account portal, and copy it into the parent directory of
  :bash:`$GUROBI_HOME`.

  .. code-block:: bash

     cd gurobi.lic /opt/gurobi910/gurobi.lic

To verify that Gurobi is properly installed, run the **gurobi.sh** shell script:

.. code-block:: bash

   .$GUROBI_HOME/bin/gurobi.sh


REISE.jl
########
The package will need to be added to each user's default Julia environment. This can be
done by launching Julia and typing ``]`` to access the ``Pkg`` (the built-in package
manager) REPL environment that easily allows operations such as installing, updating
and removing packages.

.. code-block:: julia

                   _
       _       _ _(_)_     |  Documentation: https://docs.julialang.org
      (_)     | (_) (_)    |
       _ _   _| |_  __ _   |  Type "?" for help, "]?" for Pkg help.
      | | | | | | |/ _` |  |
      | | |_| | | | (_| |  |  Version 1.5.3 (2020-11-09)
     _/ |\__'_|_|_|\__'_|  |  Official https://julialang.org/ release
    |__/                   |

    julia> ]

    pkg>

From here, we recommend that you create an environment and install the dependencies
in the same state specified in the manifest (**Manifest.toml**):

.. code-block:: julia

   activate /PATH/TO/REISE.jl
   instantiate

Note that the Julia packages for the user's desired solvers need to be installed
separately. For instance, if you want to use GLPK, the GNU Linear Programming Kit
library, you will need to run:

.. code-block:: julia

  import Pkg
  Pkg.add("GLPK")

Then, create a :bash:`JULIA_PROJECT` environment variable that points to
:bash:`PATH/TO/REISE.jl`.

To verify that the package has been successfully installed, open a new instance of
Julia and verify that the REISE package can load without any errors with the following
command:

.. code-block:: julia

   using REISE


Python
######
We strongly recommend that you install Python in order to be able to use the command
line interface we developed to run simulations but most importantly to extract the data
generated by the simulation.

The scripts located in ``pyreisejl`` depend on several packages. Those are specified
in the **requirements.txt**, file and can be installed using:

.. code-block:: bash

   pip install -r requirements.txt

To verify that the Python scripts can successfully run, open a Python interpreter and
run the following commands:

.. code-block:: python

   from julia.api import Julia
   Julia(compiled_modules=False)
   from julia import REISE

Note that the final import of REISE may take a couple of minutes to complete.


Docker
++++++
The easiest way to setup this engine is within a Docker image.

There is an included **Dockerfile** that can be used to build the Docker image. With
the Docker daemon installed and running, do:

.. code-block:: bash

   docker build . -t reisejl

To run the Docker image, you will need to mount two volumes; one containing the Gurobi
license file and another containing the necessary input files for the engine.

.. code-block:: bash

   docker run -it `
   -v /path/to/gurobi.lic:/usr/share/gurobi_license `
   -v /path/to/input/data:/path/to/input/data `
   reisejl bash

You are ready to run simulation as demonstrated in the :doc:`usage` section.
