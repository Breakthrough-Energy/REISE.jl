def sec2hms(seconds):
    """Converts seconds to hours, minutes, seconds

    :param int seconds: number of seconds
    :return: (*tuple*) -- first element is number of hour(s), second is number
        od minutes(s) and third is number of second(s)
    :raises TypeError: if argument is not an integer.
    """
    if not isinstance(seconds, int):
        raise TypeError('seconds must be an integer')

    minutes, seconds = divmod(seconds, 60)
    hours, minutes = divmod(minutes, 60)

    return hours, minutes, seconds
