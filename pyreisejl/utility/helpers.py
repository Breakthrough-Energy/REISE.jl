import h5py
import numpy as np


class WrongNumberOfArguments(TypeError):
    """To be used when the wrong number of arguments are specified at command line."""

    pass


def sec2hms(seconds):
    """Converts seconds to hours, minutes, seconds

    :param int seconds: number of seconds
    :return: (*tuple*) -- first element is number of hour(s), second is number
        od minutes(s) and third is number of second(s)
    :raises TypeError: if argument is not an integer.
    """
    if not isinstance(seconds, int):
        raise TypeError("seconds must be an integer")

    minutes, seconds = divmod(seconds, 60)
    hours, minutes = divmod(minutes, 60)

    return hours, minutes, seconds


def load_mat73(filename):
    """Load a HDF5 matfile, and convert to a nested dict of numpy arrays.

    :param str filename: path to file which will be loaded.
    :return: (*dict*) -- A possibly nested dictionary of numpy arrays.
    """

    def convert(path="/"):
        """A recursive walk through the HDF5 structure.

        :param str path: traverse from where in the HDF5 tree, default is '/'.
        :return: (*dict*) -- A possibly nested dictionary of numpy arrays.
        """
        output = {}
        references[path] = output = {}
        for k, v in f[path].items():
            if type(v).__name__ == "Group":
                output[k] = convert("{path}/{k}".format(path=path, k=k))
                continue
            # Retrieve numpy array from h5py_hl.dataset.Dataset
            data = v[()]
            if data.dtype == "object":
                # Extract values from HDF5 object references
                original_dims = data.shape
                data = np.array([f[r][()] for r in data.flat])
                # For any entry that is a uint16 array object, convert to str
                data = np.array(
                    [
                        "".join([str(c[0]) for c in np.char.mod("%c", array)])
                        if array.dtype == np.uint16
                        else array
                        for array in data
                    ]
                )
                # If data is all strs, set dtype to object to save a cell array
                if data.dtype.kind in {"U", "S"}:
                    data = np.array(data, dtype=np.object)
                # Un-flatten arrays which had been flattened
                if len(original_dims) > 1:
                    data = data.reshape(original_dims)
            if data.ndim >= 2:
                # Convert multi-dimensional arrays into numpy indexing
                data = data.swapaxes(-1, -2)
            else:
                # Convert single-dimension arrays to N x 1, avoid saving 1 x N
                data = np.expand_dims(data, axis=1)
            output[k] = data
        return output

    references = {}
    with h5py.File(filename, "r") as f:
        return convert()
