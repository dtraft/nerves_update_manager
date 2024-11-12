[![Test](https://github.com/dtraft/update_manager/actions/workflows/test.yml/badge.svg)](https://github.com/dtraft/update_manager/actions/workflows/test.yml)
[![Hex.pm Version](https://img.shields.io/hexpm/v/nerves_update_manager.svg?style=flat)](https://hex.pm/packages/nerves_update_manager)

# Nerves Update Manager

## About

This package provides the base functionality for allowing Nerves Firmware systems
to update itself "over the air", without having to take out the microSD
card.  Unlike Nerves Hub which uses a "push" pattern, this packages uses "pull" pattern,
where the firmware itself checks to see if new versions are available and determines
if/when to download and install them.

## Contributing

Contributions are welcome for this project!  You can 
[open an issue](https://github.com/dtraft/nerves_update_manager/issues) to report a bug or request
a feature enhancement.  Code contributions are also welcomed, and can be
submitted by forking this repository and creating a pull request.
