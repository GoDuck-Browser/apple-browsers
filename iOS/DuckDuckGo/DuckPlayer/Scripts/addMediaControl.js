(function() {
    // Block video playback before anything else loads
    const blockPlayback = function(event) {
        event.preventDefault();
        event.stopPropagation();
        return false;
    };

    // Capture play events at the earliest possible moment
    document.addEventListener('play', blockPlayback, true);
    document.addEventListener('playing', blockPlayback, true);
    
    // Block HTML5 video/audio playback methods
    if (typeof HTMLMediaElement !== 'undefined') {
        const origPlay = HTMLMediaElement.prototype.play;
        HTMLMediaElement.prototype.play = function() {
            this.pause();
            return Promise.reject(new Error('Playback blocked'));
        };
        
        // Override load to ensure media starts paused
        const origLoad = HTMLMediaElement.prototype.load;
        HTMLMediaElement.prototype.load = function() {
            this.autoplay = false;
            this.pause();
            return origLoad.apply(this, arguments);
        };
    }

    function addMediaControl() {
        let userInitiated = false;

        // Listen for user interactions that may lead to playback
        ['touchstart'].forEach(eventType => {
            document.addEventListener(eventType, () => {
                userInitiated = true;
                document.removeEventListener('play', blockPlayback, true);
                document.removeEventListener('playing', blockPlayback, true);
                
                // Reset HTMLMediaElement.prototype.play
                if (typeof HTMLMediaElement !== 'undefined') {
                    HTMLMediaElement.prototype.play = origPlay;
                }

                // Unmute all media elements when user interacts
                document.querySelectorAll('audio, video').forEach(media => {
                    media.muted = false;
                });

                // Reset after a short delay
                setTimeout(() => {
                    userInitiated = false;
                }, 500);
            }, true);
        });

        // Function to aggressively pause and mute all media
        function pauseAndMuteAllMedia() {
            document.querySelectorAll('audio, video').forEach(media => {
                media.pause();
                media.muted = true;
                media.autoplay = false;
                media.setAttribute('autoplay', 'false');
                // Also prevent playback via play() method
                media.play = function() {
                    return Promise.reject(new Error('Playback blocked'));
                };
            });
        }

        // Run immediately
        pauseAndMuteAllMedia();

        // Monitor DOM for newly added media elements
        const observer = new MutationObserver(mutations => {
            mutations.forEach(mutation => {
                // Check for attribute modifications
                if (mutation.type === 'attributes' && 
                    (mutation.target.tagName === 'VIDEO' || mutation.target.tagName === 'AUDIO')) {
                    if (!userInitiated) {
                        mutation.target.pause();
                        mutation.target.muted = true;
                        mutation.target.autoplay = false;
                    }
                }
                
                // Check for added nodes
                mutation.addedNodes.forEach(node => {
                    if (node.tagName === 'AUDIO' || node.tagName === 'VIDEO') {
                        if (!userInitiated) {
                            node.pause();
                            node.muted = true;
                            node.autoplay = false;
                            node.setAttribute('autoplay', 'false');
                        }
                    } else if (node.querySelectorAll) {
                        node.querySelectorAll('audio, video').forEach(media => {
                            if (!userInitiated) {
                                media.pause();
                                media.muted = true;
                                media.autoplay = false;
                                media.setAttribute('autoplay', 'false');
                            }
                        });
                    }
                });
            });
        });

        observer.observe(document.documentElement || document.body, { 
            childList: true, 
            subtree: true,
            attributes: true,
            attributeFilter: ['autoplay', 'src', 'playing']
        });
    }

    // Run as early as possible
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', addMediaControl);
    } else {
        addMediaControl();
    }
})();