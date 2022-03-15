System Requirements
-------------------
Large simulations can require significant amounts of RAM. The amount of necessary RAM
is proportional to both the size of the electric grid and the duration of the interval
considered for the simulation.

As a general estimate, 1-2 GB of RAM is needed per hour in the interval in a simulation
across the entire USA grid. For example, a 24-hour interval would require 24-48 GB of
RAM; if only 16 GB of RAM is available, consider using a time interval of 8 hours or
less as that would take 8-16 GB of RAM.

The memory necessary would also be proportional to the size of grid used. Since the
Western interconnect is roughly 8 times smaller than the entire USA grid, a simulation
ran in this interconnect with a 24-hour interval would require ~3-6 GB of RAM.
