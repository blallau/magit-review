# magit-review

Emacs Magit plugin for git review command

# Dependencies

* magit 2.4.0

# Installation

Download `magit-review.el` and ensure it is in a directory in your `load-path`.

Put something like this in your .emacs

	(require 'magit-review)
	;; Gerrit URL
	(setq magit-review-gerrit-url "https://review.openstack.org/#q,%s,n,z")
	;; Gerrit remote name can be set with:
	(setq magit-review-remote "gerrit")

# Running

M-x magit-status

# Magit Review Configuration

For simple setups, it should be enough to set the default value for
`magit-review-gerrit-url` and `magit-review-remote` as shown above.

For per project configurations, consider using buffer local or directory local
variables.


`/home/dev/code/prj1/.dir-locals.el`:

```
((magit-mode .
      ((magit-review-gerrit-url . "https://review.openstack.org/#q,%s,n,z")
       (magit-review-remote . "gerrit"))))
```

# Author

Bertrand Lallau  ( bertrand.lallau@gmail.com )

# Links

https://github.com/blallau/magit-review

* Inspired by :

    * https://github.com/terranpro/magit-gerrit

# Acknowledgements

Thanks for using and improving magit-review! Enjoy!

Please help improve magit-review! Pull requests welcomed!
