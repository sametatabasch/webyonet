"""Webyonet paket tanımı."""

from setuptools import setup, find_packages

from webyonet import __version__

setup(
    name="webyonet",
    version=__version__,
    author="Samet ATABAŞ",
    author_email="admin@gencbilisim.net",
    description="Web Sitesi Yönetim Aracı",
    long_description=open("readme.md", encoding="utf-8").read(),
    long_description_content_type="text/markdown",
    packages=find_packages(),
    package_data={
        "webyonet": ["templates/*.conf"],
    },
    python_requires=">=3.10",
    install_requires=[
        "PyYAML>=6.0",
        "requests>=2.28",
    ],
    entry_points={
        "console_scripts": [
            "webyonet=webyonet.cli:main",
        ],
    },
    classifiers=[
        "Programming Language :: Python :: 3",
        "Operating System :: POSIX :: Linux",
        "License :: OSI Approved :: MIT License",
        "Environment :: Console",
    ],
)
