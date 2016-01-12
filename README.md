# magit-review

Emacs Magit plugin for git review command

# Dependencies

* magit 2.4.0
* projectile 0.13.0

# Installation

Download `magit-review.el` and ensure it is in a directory in your `load-path`.

Put something like this in your .emacs


	(require 'magit-review)
	;; Gerrit URL
	(setq gerrit-review-url "https://review.openstack.org/#q,%s,n,z")
	;; Gerrit remote name can be set with:
	(setq magit-review-remote "gerrit")

# Running

M-x magit-status

# Links

https://github.com/blallau/magit-review

* Inspired by :

    * https://github.com/terranpro/magit-gerrit

# Author

Bertrand Lallau  ( bertrand.lallau@gmail.com )

# Acknowledgements

Thanks for using and improving magit-review! Enjoy!

Please help improve magit-review! Pull requests welcomed!
