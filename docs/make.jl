using Documenter, AbstractMultiscaleTransforms
using Documenter: Remotes

DocMeta.setdocmeta!(AbstractMultiscaleTransforms, :DocTestSetup, :(using AbstractMultiscaleTransforms); recursive = true)

makedocs(;
    modules = [AbstractMultiscaleTransforms],
    sitename = "AbstractMultiscaleTransforms.jl",
    repo = Remotes.GitHub("hakkelt", "AbstractMultiscaleTransforms.jl"),
    authors = "Tamás Hakkel",
    format = Documenter.HTML(; canonical = "https://hakkelt.github.io/AbstractMultiscaleTransforms.jl"),
    pages = [
        "Home" => "index.md",
        "Implement a transform" => "implement.md",
        "Concepts" => "concepts.md",
        "API reference" => "api.md",
    ],
    checkdocs = :public,
)

deploydocs(; repo = "github.com/hakkelt/AbstractMultiscaleTransforms.jl", devbranch = "master")
