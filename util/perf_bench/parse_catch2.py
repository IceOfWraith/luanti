#!/usr/bin/env python3
# usage: parse_catch2.py catch2.xml -> TSV: testcase \t benchmark \t mean_ns \t stddev_ns
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
for tc in root.iter("TestCase"):
    for sec_path, br in [(None, b) for b in tc.iter("BenchmarkResults")]:
        mean = br.find("mean"); sd = br.find("standardDeviation")
        print(f"{tc.get('name')}\t{br.get('name')}\t{float(mean.get('value')):.1f}\t{float(sd.get('value')):.1f}")
