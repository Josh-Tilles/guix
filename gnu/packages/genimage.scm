;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2018 Danny Milosavljevic <dannym@scratchpost.org>
;;; Copyright © 2021 Vincent Legoll <vincent.legoll@gmail.com>
;;; Copyright © 2021 Tobias Geerinckx-Rice <me@tobias.gr>
;;;
;;; This file is part of GNU Guix.
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (gnu packages genimage)
  #:use-module (guix utils)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (guix build utils)
  #:use-module (gnu packages)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages bootloaders)
  #:use-module (gnu packages cdrom)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages cpio)
  #:use-module (gnu packages disk)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages mtools)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages textutils)
  #:use-module (gnu packages virtualization))

(define-public genimage
  (package
    (name "genimage")
    (version "11")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/pengutronix/genimage")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "15jmh17lvm3jw9c92bjarly7iwhmnfl322d91mprfv10ppb9ip54"))
              ;; will be shipped with release 14
              (patches (search-patches "genimage-signedness.patch"))))
    (build-system gnu-build-system)
    (arguments
     `(#:modules
       ((ice-9 match)
        ,@%gnu-build-system-modules)
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'guixify
           (lambda* (#:key inputs #:allow-other-keys)
             (map (match-lambda
                    ((input directory regexp)
                     (substitute* "config.c"
                       (((format #f "\\.def = \"(~a)\"" regexp) _ command)
                        (format #f ".def = \"~a/~a/~a\""
                                (assoc-ref inputs input) directory command)))))
                  '(("cpio"           "bin"  "cpio")
                    ("coreutils"      "bin"  "dd")
                    ("e2fsprogs"      "sbin" "debugfs|e2fsck|mke2fs|tune2fs")
                    ("genext2fs"      "bin"  "genext2fs")
                    ("cdrkit-libre"   "bin"  "genisoimage")
                    ("mtools"         "bin"  "mcopy|mmd")
                    ;; mkcramfs is obsolete.
                    ("dosfstools"     "sbin" "mkdosfs")
                    ("mtd-utils"      "sbin" "mkfs.(jffs2|ubifs)|ubinize")
                    ("squashfs-tools" "bin"  "mksquashfs")
                    ("qemu"           "bin"  "qemu-img")
                    ("tar"            "bin"  "tar")
                    ("u-boot-tools"   "bin"  "mkimage")))
             (substitute* "util.c"
               (("\"/bin/sh\"")
                (string-append "\"" (assoc-ref inputs "bash") "/bin/sh\"")))))
         (add-before 'check 'fix-failing-tests
           (lambda _
             ;; We don't have /etc/passwd so uid 0 is not known as "root".
             ;; Thus patch it out.
             (substitute* '("test/ext2test.dump"
                            "test/ext3test.dump"
                            "test/ext4test.dump"
                            "test/ext2test-percent.dump"
                            "test/mke2fs.dump")
               (("root") "unknown"))))
         (add-before 'check 'setenv-check
           (lambda _
             ;; Our container doesn't provide access to /etc/mtab
             (setenv "EXT2FS_NO_MTAB_OK" "1")
             ;; Make test reproducible
             (setenv "GENIMAGE_MKFJFFS2" "mkfs.jffs2 -U")
             (setenv "GENIMAGE_MKE2FS" "mke2fs -E no_copy_xattrs")))
         (replace 'check
           (lambda _
             (invoke "make" "TEST_LOG_COMPILER=" "check"))))))
    (native-inputs
     `(("autoconf" ,autoconf)
       ("automake" ,automake)
       ;;; Note: cramfs is obsolete.
       ("dtc" ,dtc) ; for the tests
       ("pkg-config" ,pkg-config)
       ("util-linux" ,util-linux))) ; for the tests
    (inputs
     `(("bash" ,bash)
       ("cdrkit-libre" ,cdrkit-libre)
       ("cpio" ,cpio)
       ;; Note: invoked by final executable.
       ("coreutils" ,coreutils) ; chmod, dd
       ("dosfstools" ,dosfstools)
       ("e2fsprogs" ,e2fsprogs)
       ("genext2fs" ,genext2fs)
       ("libconfuse" ,libconfuse)
       ("mtd-utils" ,mtd-utils)
       ("mtools" ,mtools)
       ("qemu" ,qemu-minimal)
       ("squashfs-tools" ,squashfs-tools)
       ("tar" ,tar)
       ("u-boot-tools" ,u-boot-tools)))
    (synopsis "Create Flash images according to specification")
    (description "@command{genimage} creates Flash images according to a
specification file.")
    (home-page "https://github.com/pengutronix/genimage")
    (license license:gpl2)))
