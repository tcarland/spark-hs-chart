The chart uses GitHub Pages to serve as a Helm repository. Note that 
the correct release should be sync'd prior to running the helm package
command.
```sh
git checkout <tag>
```

Create a package and copy it into gh-pages *docs/*
```sh
helm package .
git checkout gh-pages
cp *.tgz docs/
```

Create a Helm index for charts
```sh
helm repo index docs --url https://tcarland.github.io/spark-hs-chart/
```

