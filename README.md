# LaTeX-BoX
![LaTeX-BoX](https://raw.github.com/LaTeX-Box-Team/LaTeX-Box/master/.assets/LaTeX-BoX.png)

## This plugin provides:
- Background compilation using latexmk.
- Completion for commands, environments, labels, bibtex entries, and inline maths.
- A simple table of contents improving the navigation of large files. 
- Smart indentation.
- Highlight matching \begin/\end and \left\right pairs.
- Motion between \begin/\end and \left\right pairs with the % key.
- Motion through brackets/braces (with user-defined keys).
- Environment objects (e.g., select environement with "vie" or "vae").
- Inline math objects (e.g., select inline math with "vi$" or "va$").
- Folding of parts (part/chapter/section/etc) and environments.
- OmniCompletion for bibliography entries respects BibLaTeX's
  `\addbibresource`, `\addglobalbib` and `\addsectionbib` commands.
- The table of contents functionality does not depend anymore on the assumption
  that `\@writefile{toc}{\contentsline ...}` entries in the `*.aux` file always
  occur at the start of some line.
- Completion of `\ref{...}` commands was completely rewritten.  It is now able
  to handle `\@newlabel{label}{{number}{page}...}` entries in the `*.aux` file
  even if `number` or `page` contain arbitrary nested levels of braces.  Labels
  are additionally held in a cache per `*.aux` file, which is updated only if
  the modification time of the file changes.
- The table of contents now opens files different from the one currently being
  edited in a new buffer.  (I actually think, that this behaviour was
  implemented already, but I could not get it working.)  To make this work,
  LaTeX-Box is not loaded per buffer but globally.

This plugins aims at being lightweight and simple.  For more fully-fledged
plugins, see:
- LaTeX-Suite: vimscript#475
- AutomaticTexPlugin: vimscript#2945

## Installation
### With gmarik vundle
_https://github.com/gmarik/vundle_

Add `Plugin 'LaTeX-Box-Team/LaTeX-Box'` to your ~/.vimrc and run
`:PluginInstall` in a vim buffer. Add `!` to the command to update.

### With pathogen
_https://github.com/tpope/vim-pathogen_

Add the LaTeX-Box bundle to your bundle directory, for instance with `git
clone`.  This will typically be enough:

    cd ~/.vim/bundle
    git clone git://github.com/LaTeX-Box-Team/LaTeX-Box.git

### Without a plugin manager

Copy the directories to your `.vim/` folder.

### Windows users

Users working with (g)vim on Windows must have a Perl environment installed.
Such an environment can be downloaded at : http://strawberryperl.com/

### Installation Notes

Make sure `filetype plugin on` is set in host `.vimrc`, else LaTeX-Box
will not load.

Note that there are configurable global variables that can be put in the
`.vimrc`. These are documented, but as an example, one can have the 
table of contents open as a horizontal split by utilizing this:

    ~/.vimrc
    ...
    if s:extfname ==? "tex"
      ...
      let g:LatexBox_split_type="new"
      ...
    endif

## Mirror information

This is mirrored on 

- http://www.vim.org/scripts/script.php?script_id=3109
- https://launchpad.net/~vim-latex-box

## Example Table of Contents

![LaTeX-BoX TOC](https://raw.github.com/LaTeX-Box-Team/LaTeX-Box/master/.assets/LaTeX-BoX-TOC-demo.png)


