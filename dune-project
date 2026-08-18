(lang dune 3.20)

(name central)

(generate_opam_files)

(license MIT)

(authors "Mathieu Barbin")

(maintainers "Mathieu Barbin <opensource@mbarbin.org>")

(source
 (github mbarbin/central-cli))

(documentation "https://mbarbin.github.io/central-cli/")

(using menhir 3.0)

(implicit_transitive_deps false)

(package
 (name central)
 (synopsis "Manage history between sub-repos and their monorepo")
 (depends
  (ocaml
   (>= 5.3))
  (cmdlang
   (>= 0.0.11))
  (cmdlang-cmdliner-err-runner
   (>= 0.0.17))
  (dune-build-info
   (>= 3.20))
  (dyn
   (>= 3.20))
  (file-rewriter
   (>= 0.0.3))
  (fpath
   (>= 0.7.3))
  (fpath-sexp0
   (>= 0.4.0))
  (loc
   (>= 0.2.2))
  (menhir
   (>= 20220210))
  (pp
   (>= 2.0.0))
  (pplumbing-err
   (>= 0.0.17))
  (pplumbing-log
   (>= 0.0.17))
  (pplumbing-log-cli
   (>= 0.0.17))
  (pplumbing-pp-tty
   (>= 0.0.17))
  (print-table
   (>= 0.1.3))
  (sexplib0
   (>= v0.17))
  (spawn
   (>= v0.17))
  (volgo
   (>= 0.0.22))
  (volgo-git-unix
   (>= 0.0.22))
  (xdg
   (>= 3.20))
  (yojson
   (>= 3.0.0))))

(package
 (name central-tests)
 (synopsis "Tests and end-to-end examples for central")
 (depends
  (ocaml
   (>= 5.3))
  (central
   (= :version))
  (file-rewriter
   (>= 0.0.3))
  (fpath
   (>= 0.7.3))
  (mdexp
   (>= 0.0.20260814))
  (pplumbing-err
   (>= 0.0.17))
  (ppx_expect
   (>= v0.17))
  (volgo
   (>= 0.0.22))
  (volgo-git-unix
   (>= 0.0.22))))

(package
 (name central-dev)
 (synopsis "Package to regroup dev targets, documentation, and more")
 (allow_empty)
 (depends
  (ocaml
   (>= 5.3))
  (ocamlformat
   (= 0.29.0))
  (bisect_ppx
   (>= 2.8.3))
  (central
   (= :version))
  (central-tests
   (= :version))
  (mdexp
   (>= 0.0.20260814))
  (ppx_expect
   (>= v0.17))
  (ppx_js_style
   (>= v0.17))
  (odoc
   (>= 3.0.0))))
