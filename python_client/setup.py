from setuptools import setup, find_packages

setup(
    name='messagedb-client',
    packages=find_packages(),
    install_requires=[],
    entry_points = {
        'console_scripts': [
            'mdb-cli = messagedb.client:main',
            'mdb-webserver = messagedb.webserver:main'
        ]
    }
)
