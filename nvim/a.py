import matplotlib.pyplot as plt
import numpy as np


def graph():
    x = np.linspace(-5, 5, 500)
    y = np.sinc(x)

    plt.plot(x, y)
    plt.grid(True)
    plt.show()


if __name__ == "__main__":
    graph()
