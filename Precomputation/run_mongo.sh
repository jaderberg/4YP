#!/bin/bash
nohup ~/4YP/mongodb/bin/mongod --dbpath $1 > $2 2>&1 &