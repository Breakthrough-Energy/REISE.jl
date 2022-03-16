Formulation
-----------

Sets
++++
- :math:`B`: Set of buses indexed by :math:`b`.
- :math:`I`: Set of generators indexed by :math:`i`.
- :math:`L`: Set of transmission network branches indexed by :math:`l`.
- :math:`S`: Set of generation cost curve segments indexed by :math:`s`.
- :math:`T`: Set of time periods indexed by :math:`t`


Subsets
#######
- :math:`I^{\rm H}`: Set of hydro generators.
- :math:`I^{\rm S}`: Set of solar generators.
- :math:`I^{\rm W}`: Set of wind generators.


Variables
+++++++++
- :math:`E_{b,\,t}`: Energy available in energy storage devices at bus :math:`b` at time
  :math:`t`.
- :math:`f_{l,\,t}`: Power flowing on branch :math:`l` at time :math:`t`.
- :math:`g_{i,\,t}`: Power injected by each generator :math:`i` at time :math:`t`.
- :math:`g_{i,\,s,\,t}`: Power injected by each generator :math:`i` from cost curve
  segment :math:`i` at time :math:`t`.
- :math:`J^{\rm chg}_{b,\,t}`: Charging power of energy storage devices at bus
  :math:`b` at
  time :math:`t`.
- :math:`J^{\rm dis}_{b,\,t}`: Discharging power of energy storage devices at bus
  :math:`b`
  at time :math:`t`.
- :math:`s_{b,\,t}`: Load shed at bus :math:`b` at time :math:`t`.
- :math:`v_{l,\,t}`: Branch limit violation for branch :math:`l` at time :math:`t`.
- :math:`\delta^{\rm down}_{b,\,t}`: Amount of flexible demand curtailed at bus
  :math:`b` at time :math:`t`.
- :math:`\delta^{\rm up}_{b,\,t}`: Amount of flexible demand added at bus :math:`b` at
  time :math:`t`.
- :math:`\theta_{b,\,t}`: Voltage angle of bus :math:`b` at time :math:`t`.


Parameters
++++++++++
- :math:`a^{\rm shed}`: Binary parameter, whether load shedding is enabled.
- :math:`a^{\rm viol}`: Binary parameter, whether transmission limit violation is
  enabled.
- :math:`c_{i,\,s}`: Cost coefficient for segment :math:`s` of generator :math:`i`.
- :math:`c^{\rm min}_{i}`: Cost of running generator :math:`i` at its minimum power
  level.
- :math:`d_{b,\,t}`: Power demand at bus :math:`b` at time :math:`t`.
- :math:`E_{b,\,0}`: Initial energy available in energy storage devices at bus
  :math:`b`.
- :math:`E^{\rm max}_{b}`: Maximum energy stored in energy storage devices at bus
  :math:`b`.
- :math:`f^{\rm max}_{l}`: Maximum flow over branch :math:`l`.
- :math:`g^{\rm min}_{i}`: Minimum generation for generator :math:`i`.
- :math:`g^{\rm max}_{i,\,s}`: Width of cost curve segment :math:`s` of generator
  :math:`i`.
- :math:`J^{max}_{b}`: Maximum charging/discharging power of energy storage devices at
  bus :math:`b`.
- :math:`m^{\rm line}_{l,\,b}`: Mapping of branches to buses.
    + :math:`m^{\rm line}_{l,\,b} = 1` if branch :math:`l` starts at bus :math:`b`,
    + :math:`m^{\rm line}_{l,\,b} = -1` if branch :math:`l` ends at bus :math:`b`,
    + :math:`m^{\rm line}_{l,\,b} = 0` otherwise.
- :math:`m^{\rm unit}_{i,\,b}`: Mapping of generators to buses.
    + :math:`m^{\rm unit}_{i,\,b} = 1` if generator :math:`i` is located at bus
      :math:`b`,
    + :math:`m^{\rm unit}_{i,\,b} = 0` otherwise.
- :math:`M`: An arbitrarily-large constant, used in 'big-M' constraints to either
  constrain to :math:`0`, or relax constraint.
- :math:`p^{\rm e}`: Value of stored energy at beginning/end of interval (so that
  optimization does not automatically drain the storage by end-of-interval).
- :math:`p^{\rm s}`: Load shed penalty factor.
- :math:`p^{\rm v}`: Transmission violation penalty factor.
- :math:`r^{\rm up}_{i}`: Ramp-up limit for generator :math:`i`.
- :math:`r^{\rm down}_{i}`: Ramp-down limit for generator :math:`i`.
- :math:`w_{i,\,t}`: Power available at time :math:`t` from time-varying generator
  (hydro, wind, solar) :math:`i`.
- :math:`x_{l}`: Impedance of branch :math:`l`.
- :math:`\underline{\delta}_{b,\,t}`: Demand flexibility curtailments available (in
  MW) at bus :math:`b` at time :math:`t`.
- :math:`\overline{\delta}_{b,\,t}`: Demand flexibility additions available (in MW) at
  bus :math:`b` at time :math:`t`.
- :math:`\Delta^{\rm balance}`: The length of the rolling load balance window (in
  hours), used to account for the duration that flexible demand is deviating from the
  base demand.
- :math:`\eta^{\rm chg}_{b}`: Charging efficiency of storage device at bus :math:`b`.
- :math:`\eta^{\rm dis}_{b}`: Discharging efficiency of storage device at bus :math:`b`.


Constraints
+++++++++++
All equations apply over all entries in the indexed sets unless otherwise listed.

- :math:`0 \le g_{i,\,s,\,t} \le g^{\rm max}_{i,\,s,\,t}`: Generator segment power is
  non-negative and less than the segment width.
- :math:`0 \le s_{b,\,t} \le a^{\rm shed} \cdot
  \left ( d_{b,\,t} + \delta^{\rm up}_{b,\,t} - \delta^{\rm down}_{b,\,t} \right )`:
  Load shed is non-negative and less than the demand at that bus (including the impact
  of demand flexibility), if load shedding is enabled. If not, load shed is fixed to
  :math:`0`.
- :math:`0 \le v_{b,\,t} \le a^{\rm viol} \cdot M`: Transmission violations are non-
  negative, if they are enabled (:math:`M` is a sufficiently large constant that there
  is no effective upper limit when :math:`a^{\rm shed} = 1`). If not, they are fixed to
  :math:`0`.
- :math:`0 \le J_{b,\,t}^{\rm chg} \le J_{b}^{\rm max}`: Storage charging power is
  non-negative and limited by the maximum charging power at that bus.
- :math:`0 \le J_{b,\,t}^{\rm dis} \le J_{b}^{\rm max}`: Storage discharging power is
  non-negative and limited by the maximum discharging power at that bus.
- :math:`0 \le E_{b,\,t} \le E_{b}^{\rm max}`: Storage state-of-charge is non-negative
  and limited by the maximum state of charge at that bus.
- :math:`g_{i,\,t} = w_{i,\,t} \quad \forall i \in I^{\rm H}`: Hydro generator power is
  fixed to the profiles.
- :math:`0 \le g_{i,\,t} \le w_{i,\,t} \quad \forall i \in I^{\rm S} \cup I^{\rm W}`:
  Solar and wind generator power is non-negative and not greater than the availability
  profiles.
- :math:`\sum_{i \in I} m_{i,\,b}^{\rm unit} g_{i,\,t} +
  \sum_{l \in L} m_{l,\,b}^{\rm line} f_{l,\,t} +
  J_{b,\,t}^{\rm dis} + s_{b,\, t} + \delta_{b,\, t}^{\rm down} =
  d_{b,\,t} + J_{b,\,t}^{\rm chg} + \delta_{b,\,t}^{\rm up}`: Power balance at each bus
  :math:`b` at time :math:`t`.
- :math:`g_{i,\,t} = g_{i}^{\rm min} + \sum_{s \in \rm S} g_{i,\,s,\,t}`: Total
  generator power is equal to the minimum power plus the power from each segment.
- :math:`E_{b,\,t} = E_{b,\,t-1} + \eta_{b}^{\rm chg} J_{b,\, t}^{\rm chg} -
  \frac{1}{\eta_{b}^{\rm dis}} J_{b,\,t}^{\rm dis}`: Conservation of energy for energy
  storage state-of-charge.
- :math:`g_{i,\,t} - g_{i,\,t-1} \le r_{i}^{\rm up}`: Ramp-up constraint.
- :math:`g_{i,\,t} - g_{i,\,t-1} \ge r_{i}^{\rm down}`: Ramp-down constraint.
- :math:`-\left ( f_{l}^{\rm max} + v_{l,\,t} \right ) \le f_{l,\,t} \le
  \left ( f_{l}^{\rm max} + v_{l,\,t} \right )`: Power flow over each branch is limited
  by the branch power limit, and can only exceed this value by using the 'violation'
  variable (if enabled),
  which is penalized in the objective function.
- :math:`f_{l,\,t} = \frac{1}{x_{l}} \sum_{b \in B} m_{l,\,b}^{\rm line}
  \theta_{b,\,t}`: Power flow over each branch is proportional to the admittance and
  the angle difference.
- :math:`0 \le \delta_{b,\,t}^{\rm down} \le \underline{\delta}_{b,\,t}`: Bound on the
  amount of demand that flexible demand resources can curtail.
- :math:`0 \le \delta_{b,\,t}^{\rm up} \le \overline{\delta}_{b,\,t}`: Bound on the
  amount of demand that flexible demand resources can add.
- :math:`\sum_{t = k}^{k + \Delta^{\rm balance}} \delta_{b,\,t}^{\rm up} -
  \delta_{b,\,t}^{\rm down} \ge 0, \quad \forall b \in B, \quad k = 1, ..., |T| -
  \Delta^{\rm balance}`: Rolling load balance for flexible demand resources; used to
  restrict the time that flexible demand resources can deviate from the base demand.
- :math:`\sum_{t \in T} \delta_{b,\,t}^{\rm up} - \delta_{b,\,t}^{\rm down} \ge 0,
  \quad \forall b \in B`: Interval load balance for flexible demand resources.


Objective Function
++++++++++++++++++
:math:`\min \left [ \sum_{t \in T} \sum_{i \in I} \left [ C_{i}^{\rm min} +
\sum_{s \in \rm S} c_{i,\,s} g_{i,\,s,\,t} \right ] +
p^{\rm s} \sum_{t \in T} \sum_{b \in B} s_{b,\,t} +
p^{\rm v} \sum_{t \in T} \sum_{l \in L} v_{l,\,t} +
p^{\rm e} \sum_{b \in B} \left [ E_{b,\,0} - E_{b,\,|T|} \right ] \right ]`

There are four main components to the objective function:

- :math:`\sum_{t \in T} \sum_{i \in I} [ C_{i}^{\rm min} + \sum_{s \in \rm S} c_{i,\,s}
  g_{i,\,s,\,t} ]`: The cost of operating generators, fixed costs plus variable costs,
  which can consist of several cost curve segments for each generator.
- :math:`p^{\rm s} \sum_{t \in T} \sum_{b \in B} s_{b,\,t}`: Penalty for load shedding
  (if load shedding is enabled).
- :math:`p^{\rm v} \sum_{t \in T} \sum_{l \in L} v_{l,\,t}`: Penalty for transmission
  line limit violations (if transmission violations are enabled).
- :math:`p^{\rm e} \sum_{b \in B} \left [ E_{b,\,0} - E_{b,\,|T|} \right ]`: Penalty for
  ending the interval with less stored energy than the start, or reward for ending with
  more.
