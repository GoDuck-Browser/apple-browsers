(function() {
    // Store original play method globally
    const originalPlay = HTMLMediaElement.prototype.play;
    let observer = null;

    // Block video playback before anything else loads
    const blockPlayback = function(event) {
        event.preventDefault();
        event.stopPropagation();
        return false;
    };

    // Capture play events at the earliest possible moment
    document.addEventListener('play', blockPlayback, true);
    document.addEventListener('playing', blockPlayback, true);

    function startMediaControl() {
        let userInitiated = false;

        // Listen for user interactions that may lead to playback
        ['touchstart'].forEach(eventType => {
            document.addEventListener(eventType, () => {
                userInitiated = true;
                
                // Remove the early blocking listeners
                document.removeEventListener('play', blockPlayback, true);
                document.removeEventListener('playing', blockPlayback, true);

                // Unmute all media elements when user interacts
                document.querySelectorAll('audio, video').forEach(media => {
                    media.muted = false;
                });

                // Reset after a short delay to prevent indefinite allowance
                setTimeout(() => {
                    userInitiated = false;
                }, 500);
            }, true);  // Capture phase to detect early
        });

        // Store original play method for later restoration
        HTMLMediaElement.prototype._originalPlay = originalPlay;

        // Override play to detect and conditionally allow playback
        HTMLMediaElement.prototype.play = function() {
            if (userInitiated) {
                // User-triggered playback is allowed, so disconnect the observer and unmute
                if (observer) {
                    observer.disconnect();
                }
                this.muted = false;  // Unmute the specific media element being played
                return originalPlay.apply(this, arguments);
            } else {
                // Block programmatic playback
                this.pause();
                return Promise.reject(new Error("Playback blocked: Not user-initiated"));
            }
        };

        // Initial pause of all media
        function pauseAndMuteAllMedia() {
            document.querySelectorAll('audio, video').forEach(media => {
                media.pause();
                media.muted = true;
            });
        }

        pauseAndMuteAllMedia();

        // Monitor DOM for newly added media elements
        observer = new MutationObserver(mutations => {
            mutations.forEach(mutation => {
                mutation.addedNodes.forEach(node => {
                    if (node.tagName === 'AUDIO' || node.tagName === 'VIDEO') {
                        if (!userInitiated) {  // Only mute if not user-initiated
                            node.pause();
                            node.muted = true;
                        }
                    } else if (node.querySelectorAll) {
                        node.querySelectorAll('audio, video').forEach(media => {
                            if (!userInitiated) {  // Only mute if not user-initiated
                                media.pause();
                                media.muted = true;
                            }
                        });
                    }
                });
            });
        });

        // Store observer for cleanup
        window._mediaObserver = observer;
        observer.observe(document.body, { childList: true, subtree: true });
    }

    // Cleanup function that restores original state
    function stopMediaControl() {
        // Restore original play method
        if (HTMLMediaElement.prototype._originalPlay) {
            HTMLMediaElement.prototype.play = HTMLMediaElement.prototype._originalPlay;
            delete HTMLMediaElement.prototype._originalPlay;
        }
        
        // Remove event listeners
        document.removeEventListener('play', blockPlayback, true);
        document.removeEventListener('playing', blockPlayback, true);
        
        // Clean up observer
        if (window._mediaObserver) {
            window._mediaObserver.disconnect();
            delete window._mediaObserver;
        }
        if (observer) {
            observer.disconnect();
            observer = null;
        }
    }

    // Run as early as possible, but also clean up if needed
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', startMediaControl);
        // Clean up when navigating away
        window.addEventListener('beforeunload', stopMediaControl);
    } else {
        startMediaControl();
        window.addEventListener('beforeunload', stopMediaControl);
    }
})();