pragma Singleton
import QtQuick
import Quickshell
import qs.services

// Quotes slideshow state — a rotating deck of short, attributed factoids from
// computing legends (Ken Thompson & co.), paced by a repeating timer. The
// desktop widget (notBar/background/DesktopQuotes.qml) just renders
// current.q / current.a; nothing here persists.
Singleton {
    id: root

    // ── the deck ──
    readonly property var quotes: [
        {
            q: "When in doubt, use brute force.",
            a: "Ken Thompson"
        },
        {
            q: "One of my most productive days was throwing away 1,000 lines of code.",
            a: "Ken Thompson"
        },
        {
            q: "Unix is basically a simple operating system, but you have to be a genius to understand the simplicity.",
            a: "Dennis Ritchie"
        },
        {
            q: "Debugging is twice as hard as writing the code in the first place. Therefore, if you write the code as cleverly as possible, you are, by definition, not smart enough to debug it.",
            a: "Brian Kernighan"
        },
        {
            q: "Talk is cheap. Show me the code.",
            a: "Linus Torvalds"
        },
        {
            q: "Real programmers can write assembly code in any language.",
            a: "Linus Torvalds"
        },
        {
            q: "The most dangerous phrase in the language is: \u201cWe\u2019ve always done it this way.\u201d",
            a: "Grace Hopper"
        },
        {
            q: "We can only see a short distance ahead, but we can see plenty there that needs to be done.",
            a: "Alan Turing"
        },
        {
            q: "Those who can imagine anything, can create the impossible.",
            a: "Alan Turing"
        },
        {
            q: "Simplicity is prerequisite for reliability.",
            a: "Edsger W. Dijkstra"
        },
        {
            q: "If debugging is the process of removing software bugs, then programming must be the process of putting them in.",
            a: "Edsger W. Dijkstra"
        },
        {
            q: "Premature optimization is the root of all evil.",
            a: "Donald Knuth"
        },
        {
            q: "An algorithm must be seen to be believed.",
            a: "Donald Knuth"
        },
        {
            q: "There are only two kinds of languages: the ones people complain about and the ones nobody uses.",
            a: "Bjarne Stroustrup"
        },
        {
            q: "There are only two hard things in Computer Science: cache invalidation and naming things.",
            a: "Phil Karlton"
        },
        {
            q: "There are two ways of constructing a software design: one way is to make it so simple that there are obviously no deficiencies, and the other way is to make it so complicated that there are no obvious deficiencies.",
            a: "C. A. R. Hoare"
        },
        {
            q: "Programs must be written for people to read, and only incidentally for machines to execute.",
            a: "Harold Abelson"
        },
        {
            q: "The purpose of computing is insight, not numbers.",
            a: "Richard Hamming"
        },
        {
            q: "The best way to predict the future is to invent it.",
            a: "Alan Kay"
        },
        {
            q: "Akili Nyingi Huondoa Maarifa",
            a: "Mhenga"
        },
        {
            q: "A computer is like a bicycle for the mind.",
            a: "Steve Jobs"
        },
        {
            q: "It\u2019s hard for me to get motivated by the rewards, because the work itself is the reward.",
            a: "John Carmack"
        },

        // ── more legends ──
        {
            q: "The computer was born to solve problems that did not exist before.",
            a: "Bill Gates"
        },
        {
            q: "Any sufficiently advanced technology is indistinguishable from magic.",
            a: "Arthur C. Clarke"
        },
        {
            q: "Any fool can write code that a computer can understand. Good programmers write code that humans can understand.",
            a: "Martin Fowler"
        },
        {
            q: "First, solve the problem. Then, write the code.",
            a: "John Johnson"
        },
        {
            q: "Code is like humor. When you have to explain it, it's bad.",
            a: "Cory House"
        },
        {
            q: "Make it work, make it right, make it fast.",
            a: "Kent Beck"
        },
        {
            q: "Software is a gas; it expands to fill its container.",
            a: "Nathan Myhrvold"
        },
        {
            q: "The trouble with programmers is that you can never tell what a programmer is doing until it's too late.",
            a: "Seymour Cray"
        },
        {
            q: "Controlling complexity is the essence of computer programming.",
            a: "Brian Kernighan"
        },
        {
            q: "Walking on water and developing software from a specification are easy if both are frozen.",
            a: "Edward V. Berard"
        },
        {
            q: "People who are really serious about software should make their own hardware.",
            a: "Alan Kay"
        },
        {
            q: "The most disastrous thing that you can ever learn is your first programming language.",
            a: "Alan Kay"
        },
        {
            q: "Perfection is achieved not when there is nothing more to add, but when there is nothing more to take away.",
            a: "Antoine de Saint-Exupery"
        }
    ]

    // ── the hyprland group ──
    // drawn from the compositor's own splash rotator (Splashes.hpp) and
    // vaxry's interviews/blog — the ethos of the desktop this bar runs on
    readonly property var hyprQuotes: [
        {
            q: "Hello everyone, this is YOUR daily dose of 'read the wiki'.",
            a: "vaxry"
        },
        {
            q: "I commit too often, people can't catch up lmao.",
            a: "vaxry"
        },
        {
            q: "Why no work? Bro, I haven't hacked your PC to get live feeds yet.",
            a: "vaxry"
        },
        {
            q: "Disabling the Hyprland logo is a war crime.",
            a: "vaxry"
        },
        {
            q: "The AUR packages always work, except for the times they don't.",
            a: "Hyprland splash"
        },
        {
            q: "Woo, animations!",
            a: "Hyprland splash"
        },
        {
            q: "Funny animation compositor woo.",
            a: "Hyprland splash"
        },
        {
            q: "A dynamic tiling Wayland compositor that doesn't wrack your brain.",
            a: "Hyprland"
        },
        {
            q: "Great tiling and eyecandy — something people have wanted for years.",
            a: "vaxry"
        },
        {
            q: "The lower you go, the more amusing it gets. Just kidding — you'll only go insane.",
            a: "vaxerski"
        }
    ]

    // ── the funny group ──
    // tongue-in-cheek programmer folklore / meme canon; off by adding lots
    // of extra comments that don't take themselves too seriously
    readonly property var funQuotes: [
        {
            q: "It works on my machine.",
            a: "every developer"
        },
        {
            q: "There are 10 types of people in this world: those who understand binary and those who don't.",
            a: "folklore"
        },
        {
            q: "A SQL query walks into a bar, goes up to two tables and asks, 'Can I join you?'",
            a: "classic"
        },
        {
            q: "I would love to change the world, but they won't give me the source code.",
            a: "classic"
        },
        {
            q: "The best thing about a boolean is that even if you're wrong, you're only off by a bit.",
            a: "classic"
        },
        {
            q: "99 little bugs in the code, 99 little bugs. Take one down, patch it around, 127 little bugs in the code.",
            a: "folklore"
        },
        {
            q: "sudo rm -rf /: the fastest, most permanent disk cleanup.",
            a: "classic"
        },
        {
            q: "Real programmers count from 0.",
            a: "classic"
        },
        {
            q: "It's not a bug — it's an undocumented feature.",
            a: "classic"
        },
        {
            q: "A programmer is a machine that turns coffee into code.",
            a: "classic"
        },
        {
            q: "I'm not arguing, I'm just explaining why I'm right — every commit message I've ever written.",
            a: "anonymous"
        },
        {
            q: "Why do programmers fear sunlight? It brings too many bugs out of the dark.",
            a: "classic"
        }
    ]

    // ── group toggles (persisted) ──
    // extra decks are "funny extra comments" (meme canon, on by default) and
    // hyprland splashes. Toggling a group jumps to the next quote so the
    // change is seen immediately.
    property bool showFun: Prefs.prefs.quotesShowFun ?? true
    onShowFunChanged: {
        Prefs.prefs.quotesShowFun = showFun;
        Prefs.write();
        root.next();
    }

    property bool showHypr: Prefs.prefs.quotesShowHypr ?? true
    onShowHyprChanged: {
        Prefs.prefs.quotesShowHypr = showHypr;
        Prefs.write();
        root.next();
    }

    // combined deck = enabled groups concatenated; index cycles across it
    readonly property var deck: root.quotes.concat(
        root.showHypr ? root.hyprQuotes : [],
        root.showFun ? root.funQuotes : [])

    readonly property int total: root.deck.length

    property int index: 0
    readonly property var current: root.deck[root.index % root.total]

    // ── display prefs (persisted) ──
    // glass chip behind the quote — off by default so the text floats bare
    property bool showBg: Prefs.prefs.quotesShowBg ?? false
    onShowBgChanged: {
        Prefs.prefs.quotesShowBg = showBg;
        Prefs.write();
    }

    property string quoteFont: Prefs.prefs.quotesQuoteFont ?? "Quicksand"
    onQuoteFontChanged: {
        Prefs.prefs.quotesQuoteFont = quoteFont;
        Prefs.write();
    }

    property string authorFont: Prefs.prefs.quotesAuthorFont ?? "Quicksand"
    onAuthorFontChanged: {
        Prefs.prefs.quotesAuthorFont = authorFont;
        Prefs.write();
    }

    // slideshow pacing (ms on screen per quote)
    property int intervalMs: Prefs.prefs.quotesIntervalMs ?? 9000
    onIntervalMsChanged: {
        Prefs.prefs.quotesIntervalMs = intervalMs;
        Prefs.write();
    }

    function next() {
        root.index = (root.index + 1) % root.total;
    }
    function previous() {
        root.index = (root.index + root.total - 1) % root.total;
    }

    Timer {
        id: cycleTimer
        interval: root.intervalMs
        repeat: true
        running: true
        onTriggered: root.next()
    }
}
