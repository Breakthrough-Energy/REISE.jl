import h5py
import numpy as np


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


def string_from_int_matrix(array):
    """Convert matrices of integers to strings.

    :param numpy.ndarray array: array of ints, each representing a character
    :return: (*str*) -- string of converter characters.
    """
    return ''.join([str(c[0]) for c in np.char.mod('%c', array)])


def load_mat73(filename):
    """Load a HDF5 matfile, and convert to a nested dict of numpy arrays.

    :param str filename: path to file which will be loaded.
    :return: (*dict*) -- A possibly nested dictionary of numpy arrays.
    """
    def convert(path='/'):
        """A recursive walk through the HDF5 structure.

        :param str path: traverse from where in the HDF5 tree, default is '/'.
        :return: (*dict*) -- A possibly nested dictionary of numpy arrays.
        """
        output = {}
        references[path] = output = {}
        for k, v in f[path].items():
            if type(v).__name__ == 'Group':
                output[k] = convert('{path}/{k}'.format(path=path, k=k))
                continue
            # Retrieve numpy array from h5py_hl.dataset.Dataset
            data = v[()]
            if data.dtype == 'object':
                # Extract values from HDF5 object references
                data = np.array([f[r][()] for r in data.flat])
            if data.ndim >= 2:
                # Convert multi-dimensional arrays into numpy indexing
                data = data.swapaxes(-1, -2)
            if data[0].dtype == np.uint16:
                # Convert matrices of integers to strings
                data = np.array([string_from_int_matrix(arr) for arr in data])
            output[k] = data
        return output

    references = {}
    with h5py.File(filename, 'r') as f:
        return convert()
