import pytest


@pytest.mark.skip(reason="Need to run on the server")
def test():
    from pyreisejl.utility.call import launch_scenario_performance
    launch_scenario_performance('87')
