# Yakefiles -> Makefiles

`Make` is a powerful tool for managing compiling and managing other complex procedures. It is also a great tool for building pipelines. However due to its cryptic syntax `Makefiles` can be really hard to maintain. Here come `Yakefiles`: their format is a subset of `YAML`, so that it's easy to write, to read and to maintain them. 

`Yake` is a tool which parses `Yakefiles` producing corresponding `Makefiles`, thus it wraps the existing and well-tested technology making the experience with the code more pleasant. It also means portability, since `Make` is widely used on UNIX systems. `Yake` is a lightweight, simple and open-source tool with just a few necessary options. Though rather stable, it is currently in alpha.

## Install

TBD

## Quick Start Guide

First of all, make yourself familiar with YAML syntax: [here](http://www.yaml.org/spec/1.2/spec.html) is the specification, [Wikipedia article](https://en.wikipedia.org/wiki/YAML) and [a](http://docs.ansible.com/ansible/YAMLSyntax.html) [few](http://salt.readthedocs.org/en/stable/topics/yaml/index.html) tutorials. (Don't worry, there's not so much to learn about YAML.)

Now that you understand YAML files, let's build a basic pipeline.

## Tutorial

```sh
yake --rule-titles pipeline.yake
```

### 
