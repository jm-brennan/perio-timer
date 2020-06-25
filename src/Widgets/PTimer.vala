using Gtk;

namespace PerioTimer.Widgets {

public struct Stage {
    public int hours;
    public int minutes;
    public int seconds;
    public int64 startTime;
    public int64 timeLeft;
    public float r;
    public float g;
    public float b;
}

public class PTimer {
    private Overlay? overlay = null;
    private TimerAnimation? ta = null;
    public InputManager? im = null;
    private TextView? textView = null;
    private Box? timerView = null;
    private Box? settingsView = null;
    private bool active = false;
    private int update_interval = 1000;
    //private int64 timerDuration = 0;
    //private int64 startTime = 0;
    //private int64 endTime = 0;
    //private int hours = 0;
    //private int minutes = 0;
    //private int seconds = 0;
    private string displayString = "";
    string[] smh = new string[3];
    private bool doSeconds = false;

    // @TODO load defaults from settings
    // button setup for timer behavior settings:
    // repeat: default off
    // notification: default on
    // volume: default on
    private bool repeatStatus = false;
    private Button repeatBut = null;
    private Image repeatImOn = new Image.from_icon_name("media-playlist-repeat-symbolic", IconSize.MENU);
    private Image repeatImOff = new Image.from_icon_name("media-playlist-consecutive-symbolic", IconSize.MENU);

    private bool notificationStatus = true;
    private Button notificationBut = null;
    private Image notificationImOn = new Image.from_icon_name("notification-alert-symbolic", IconSize.MENU);
    private Image notificationImOff = new Image.from_icon_name("notification-disabled-symbolic", IconSize.MENU);

    private bool volumeStatus = true;
    private Button volumeBut = null;
    private Image volumeImOn = new Image.from_icon_name("audio-volume-high-symbolic", IconSize.MENU);
    private Image volumeImOff = new Image.from_icon_name("audio-volume-muted-symbolic", IconSize.MENU);


    // @TODO testing hvaing a text box, need to figure out input redirection
    public Entry te = null;

    // @TODO figuring out the multi stage stuff
    private const int MAX_STAGES = 4;
    private Stage[] stages = new Stage[MAX_STAGES];
    private int currentStage = 0;
    private int numStages = 1;

    public PTimer(int width, int height, int colorset) {
        im = new InputManager(this);
        timerView = new Box(Orientation.VERTICAL, 0);
        // @TODO input redirection
        timerView.set_focus_on_click(true);
        
        overlay = new Overlay();
        overlay.add_events(Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK);
        overlay.set_size_request(width, height);
        overlay.button_press_event.connect((e) => {
            this.toggle_active();
            return true;
        });
        // @TODO implement dragging leading edge of animation with this
        /*  overlay.button_release_event.connect((e) => {
            print("RELEASE\n");
            print(e.x.to_string());
            print("\n");
            print(e.y.to_string());
            return true;
        });
        overlay.leave_notify_event.connect(() => {
            print("LEFT");
            return true;
        });  */
        
        // textview needs to be wrapped in center of a 3x3 box grid to get the 
        // bottom border attribute to appear properly. Because it is added to an overlay,
        // can't just pack_start with expand=false to get proper vertical alignment,
        // and need empty widgets (just chose labels) to make left and right boundaries.
        // There may be better ways to accomplish this, but I am a gtk novice.  
        var textViewBoxV = new Box(Orientation.VERTICAL, 0);
        textViewBoxV.set_homogeneous(true);
        var textViewBoxH = new Box(Orientation.HORIZONTAL, 0);
        textViewBoxH.set_homogeneous(false);
        var rlabel = new Label("");
        var llabel = new Label("");
        
        textView = new TextView();
        textView.set_justification(Justification.CENTER);
        textView.cursor_visible = false;
        textView.set_editable(false);
        
        textViewBoxH.pack_start(llabel, false, false, 0);
        textView.set_halign(Align.CENTER);
        textView.set_valign(Align.CENTER);
        // this needs the expand properties=true so that calling set_halign will matter
        textViewBoxH.pack_start(textView, true, true, 0);
        textViewBoxH.pack_start(rlabel, false, false, 0);
        
        textViewBoxV.pack_start(textViewBoxH, false, false, 0);
        
        overlay.add(textViewBoxV);
        ta = new TimerAnimation(width, height, colorset);
        overlay.add_overlay(ta);
        make_display_string();
        timerView.pack_start(overlay, false, false, 0);
        
        te = new Entry();
        timerView.pack_start(te, false, false, 0);


        settingsView = new Box(Orientation.HORIZONTAL, 0);

        repeatBut = new Button();
        repeatBut.set_image(repeatImOff);
        repeatBut.clicked.connect(this.toggle_repeat);
        settingsView.pack_start(repeatBut, true, false, 0);

        volumeBut = new Button();
        volumeBut.set_image(volumeImOn);
        volumeBut.clicked.connect(this.toggle_volume);
        settingsView.pack_start(volumeBut, true, false, 0);

        notificationBut = new Button();
        notificationBut.set_image(notificationImOn);
        notificationBut.clicked.connect(this.toggle_notification);
        settingsView.pack_start(notificationBut, true, false, 0);

        timerView.pack_start(settingsView, true, true, 10);
    }

    public void set_input_time(string inputString) {
        if (!active){
            smh[0] = ""; // seconds
            smh[1] = ""; // minutes
            smh[2] = ""; // hours
            int smhIndex = 0;
            
            for (int i = 0; i < inputString.length; i++) {
                smhIndex = (int)Math.floorf((inputString.length - 1 - i) / 2.0f);
                if (!doSeconds) {
                    smhIndex += 1;
                }
                smh[smhIndex] = smh[smhIndex] + inputString.substring(i, 1);
            }
            
            stages[currentStage].hours = int.parse(smh[2]);
            stages[currentStage].minutes = int.parse(smh[1]);
            stages[currentStage].seconds = int.parse(smh[0]);

            make_display_string();
        }
    }

    public void new_stage() {
        if (numStages == MAX_STAGES) return;
        print("new stage\n");

        // @TODO make it so it can be added to middle of sequence (not linked list tho lol)
        currentStage = numStages;
        numStages++;

        stages[currentStage] = {0,0,0,0,0,0.0f, 0.0f, 0.0f};
    }

    public void switch_stage(int switchDirection) {
        currentStage += switchDirection;
        // make sure only traversing defined stages
        currentStage = int.max(0, currentStage);
        currentStage = int.min(currentStage, numStages-1);
        make_display_string();
    }

    public Box timer_view() { return this.timerView; }

    public void toggle_active(bool startable = false) {
        if (active) {
            set_inactive();
        } else {
            // if this toggle call does not have start privileges
            // and timer hasn't been started, just return
            if (!startable && stages[currentStage].startTime == 0) return;
            set_active();
        }
    }

    public void set_active() {
        if (active) return;
        
        // starting a timer for the first time
        if (stages[currentStage].startTime == 0) {
            stages[currentStage].timeLeft += stages[currentStage].hours * 36 * (int64)Math.pow10(8);
            stages[currentStage].timeLeft += stages[currentStage].minutes * 6 * (int64)Math.pow10(7);
            stages[currentStage].timeLeft += stages[currentStage].seconds * (int64)Math.pow10(6);
        }
        stages[currentStage].startTime = GLib.get_monotonic_time();
        active = true;
        Timeout.add(update_interval, update_time);
        ta.set_active();
    }

    public void set_inactive() {
        if (!active) return;

        stages[currentStage].timeLeft -= GLib.get_monotonic_time() - stages[currentStage].startTime;

        active = false;
        ta.set_inactive();
    }

    public void toggle_seconds() {
        if (!active){
            doSeconds = !doSeconds;
        }
    }

    public void toggle_repeat() {
        if (repeatStatus) {
            repeatBut.set_image(repeatImOff);
        } else {
            repeatBut.set_image(repeatImOn);
        }
        repeatStatus = !repeatStatus;
    }

    public void toggle_notification() {
        if (notificationStatus) {
            notificationBut.set_image(notificationImOff);
        } else {
            notificationBut.set_image(notificationImOn);
        }
        notificationStatus = !notificationStatus;
    }

    public void toggle_volume() {
        if (volumeStatus) {
            volumeBut.set_image(volumeImOff);
        } else {
            volumeBut.set_image(volumeImOn);
        }
        volumeStatus = !volumeStatus;
    }

    public void make_display_string(bool editing = true) {
        // @TODO decide whether it is a good idea to do this var thing or just access
        // the data directly like in decrement_time 
        int hours = stages[currentStage].hours;
        int minutes = stages[currentStage].minutes;
        int seconds = stages[currentStage].seconds;

        displayString = "";
        if (!active || hours > 0) {
            displayString += hours.to_string();
            displayString += "h";
        }

        if (!active || minutes > 0 || hours > 0) {
            if (!active || hours > 0) {
                displayString += " ";
            }
            displayString += minutes.to_string();
            displayString += "m";
        }

        if (!active || seconds > 0 || minutes > 0 || hours > 0) {
            if (doSeconds || active) {
                if (!active || minutes > 0 || hours > 0) {
                    displayString += " ";
                }
                displayString += seconds.to_string();
                displayString += "s";
            }
        }
        
        textView.buffer.text = displayString;
    }

    public void decrement_time() {
        stages[currentStage].seconds--;
        if (stages[currentStage].seconds < 0 && stages[currentStage].minutes > 0) {
            stages[currentStage].seconds = 59;
            stages[currentStage].minutes--;
            if (stages[currentStage].minutes < 0 && stages[currentStage].hours > 0) {
                stages[currentStage].minutes = 59;
                stages[currentStage].hours--;
                if (stages[currentStage].hours < 0) {
                    stages[currentStage].hours = 0;
                }
            } else if (stages[currentStage].minutes < 0) {
                stages[currentStage].minutes = 0;
            }
        }
    }
     
    // @TODO time drifts by about 1/10 seconds every two minutes when just doing timeouts
    private bool update_time() {
        if (active) {
            decrement_time();
            //make_display_string();
            if (stages[currentStage].seconds > 0) {
                make_display_string();
            } else {
                displayString = "DONE";
                textView.buffer.text = displayString;
                set_inactive();
            }
            
        }
        return active;
    }

}

} // end namespace