# magit-review

Emacs Magit plugin for git review command

# Dependencies

* magit 2.4.0
* projectile 0.13.0

# Installation

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
