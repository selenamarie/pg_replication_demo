#!/bin/bash


psql postgres -f cte_euler_project.sql
psql postgres -f cte_euler_project_explain.sql
