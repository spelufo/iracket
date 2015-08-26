# iracket

Work in progress. Racket kernel for jupyter notebooks.

### How to install and run

```bash

# dependencies:
# Install zeromq 3.2.5 (4.* didn't work with the racket bindings for me.)
raco pkg install zeromq
raco pkg install libuuid
raco pkg install grommet # for authentication, not used yet
pip install jupyter # I get version 4.0.4

# install the kernelspec
mkdir -p "$JUPYTER_CONFIG_DIR/kernels/racket/"
cp kernel.json "$JUPYTER_CONFIG_DIR/kernels/racket/"
edit "$JUPYTER_CONFIG_DIR/kernels/racket/kernel.json" # changing "./iracket.rkt" to where you put the file.

# run it with

jupyter console --Session.key="b''" --kernel racket

# or

jupyter notebook --Session.key="b''" --kernel racket
```

### Useful resources

- [simple_kernel](https://github.com/dsblank/simple_kernel)
- [jupyter-client docs](https://jupyter-client.readthedocs.org/en/latest/).
- [this stackoverflow thread](https://stackoverflow.com/questions/16240747/sending-messages-from-other-languages-to-an-ipython-kernel)
- [racket-zmq-examples](https://github.com/neomantic/racket-zmq-examples)


### Notes

- The messages must be multipart.
- ZMQ will block the entire thread, so we put the heartbeat socket in a differnt place.

