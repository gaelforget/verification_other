To make this work, copy the full experiment dir "global_oce_biogeo_bling"
 to your mitgcm/verification folder and then:

1) Compile with TAF in build
E.G.
  cd build
  ../../../tools/genmake2 -mods ../code_ad -of ../../../tools/build_options/linux_amd64_gfortran
  make depend
  make adall
  cd ..

2) Then in "run" dir:
  cd run
  ln -s ../input_ad/* .
  ./prepare_run
  ln -s ../build/mitgcmuv_ad .

3) RUN IT!
  ./mitgcmuv_ad >& output_adm.txt
