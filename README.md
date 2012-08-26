Fork of [LaTeX-Box](https://github.com/LaTeX-Box-Team/LaTeX-Box).
See there for more information.

The purpose of this fork was originally to fix this [issue](https://github.com/LaTeX-Box-Team/LaTeX-Box/issues/9).
In the meantime, the following behaviour of LaTeX-Box was modified:

 *  OmniCompletion for bibliography entries respects BibLaTeX's
    `\addbibresource`, `\addglobalbib` and `\addsectionbib` commands.
 *  The table of contents functionality does not depend anymore on the assumption
    that `\@writefile{toc}{\contentsline ...}` entries in the `*.aux` file always
    occur at the start of some line.
 *  Completion of `\ref{...}` commands was completely rewritten. It is now
    able to handle `\@newlabel{label}{{number}{page}...}` entries in the `*.aux`
    file even if `number` or `page` contain arbitrary nested levels of braces.
    
    Labels are additionally held in a cache per `*.aux` file, which is updated
    only if the modification time of the file changes.
 *  The table of contents now opens files different from the one currently
    being edited in a new buffer. (I actually think, that this behaviour was 
            implemented already, but I could not get it working.)
    To make this work, LaTeX-Box is not loaded per buffer but globally.
    
Furthermore, I plan the following features:

 *  Support of building in a separate directory like provided by `latexmk`'s
    `$out_dir` feature. 
    
If you have any comments, suggestions or bug reports, feel free to open an issue.

