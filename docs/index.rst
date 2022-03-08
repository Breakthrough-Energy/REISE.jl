REISE.jl
========
REISE.jl (Renewable Energy Integration Simulation Engine) is the simulation engine
developed by BES to run power-flow studies in the U.S. electric grid. REISE.jl is an
open-source package written in Julia that is available on `GitHub
<https://github.com/Breakthrough-Energy/REISE.jl>`_. It can be interfaced with the BES
software ecosystem (see `PowerSimData
<https://github.com/Breakthrough-Energy/PowerSimData>`_) or used in a standalone mode.
In both cases you will need an external optimization solver to solve the DCOPF problem.

You will find in this documentation all the information needed to install this package
and use it. We also provide the formulation of the objective function along with
its constraints.


.. role:: python(code)
  :language: python
  :class: highlight

.. role:: julia(code)
  :language: julia

.. role:: bash(code)
   :language: bash


.. contents:: :local:


.. include::
   requirements.rst

.. include::
   installation.rst

.. include::
   usage.rst

.. include::
   formulation.rst


.. _Julia: https://julialang.org/
.. _Python: https://www.python.org/
.. _Gurobi: https://www.gurobi.com
.. _Jump: https://jump.dev/JuMP.jl/stable/
.. _Docker: https://docs.docker.com/
.. _Zenodo: https://zenodo.org/record/3530898
.. _MATPOWER: https://matpower.org/
