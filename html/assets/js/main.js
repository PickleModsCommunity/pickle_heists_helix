const COLORS = [
    {    
        active: "linear-gradient(to right, rgb(128, 0, 0) 0%, red 45%, red 55%, rgb(128, 0, 0))",
        inactive: "linear-gradient(to right, rgb(48, 0, 0) 0%, rgb(128, 0, 0) 45%, rgb(128, 0, 0) 55%, rgb(48, 0, 0))",
    },
    {    
        active: "linear-gradient(to right, rgb(88, 88, 0) 0%, yellow 45%, yellow 55%, rgb(88, 88, 0))",
        inactive: "linear-gradient(to right, rgb(48, 48, 0) 0%, rgb(88, 88, 0) 45%, rgb(88, 88, 0) 55%, rgb(48, 48, 0))",
    },
    {    
        active: "linear-gradient(to right, rgb(0, 88, 0) 0%, green 45%, green 55%, rgb(0, 88, 0))",
        inactive: "linear-gradient(to right, rgb(0, 48, 0) 0%, rgb(0, 88, 0) 45%, rgb(0, 88, 0) 55%, rgb(0, 48, 0))",
    },
    {    
        active: "linear-gradient(to right, rgb(35, 65, 90) 0%, rgb(70, 130, 180) 45%, rgb(70, 130, 180) 55%, rgb(35, 65, 90))",
        inactive: "linear-gradient(to right, rgb(18, 32, 45) 0%, rgb(35, 65, 90) 45%, rgb(35, 65, 90) 55%, rgb(18, 32, 45))",
    },
    {    
        active: "linear-gradient(to right, #A36A00 0%, #FFA500 45%, #FFA500 55%, #A36A00)",
        inactive: "linear-gradient(to right, #754C00 0%, #A36A00 45%, #A36A00 55%, #754C00)",
    },
];

var doorStatus = false;
var mouse = {x: 0, y: 0};
var wires = [];
var currentWeld;
var currentTimer;
var currentTimerLoop;
var currentGame;
var audioInstances = {};

function SetDoor(bool, cb) {
    doorStatus = bool;
    if (bool) {
        $("#am-overlay").addClass("active");
        setTimeout(function() {
            $("#am-overlay").css("background-image", "none");
        }, 900)
    }
    else {
        $("#am-overlay").removeClass("active");
        setTimeout(function() {
            $("#am-overlay").css("background-image", `url("assets/images/hazard.png")`);
        }, 750)
    }
    if (!cb) return;
    setTimeout(function() {
        cb()
    }, 1000)
}

function RepeatString(str, count) {
    var finalStr = "";
    for (var i=0; i<count; i++) {
        finalStr += str;
    }
    return finalStr;
}

function randomInt(max) {
    return Math.floor(Math.random() * (max + 1))
}

function IsIntInRange(number, /**/) {
    var args = arguments;
    for(var i=0; i<args.length; i++){
        if (args[i] == number) {
            return true;
        }
    }
    return false;
}

function SetWeldPosition(x, y) {
    let div = document.getElementById('ams-welding');
    div.style.left = x + 'px'; 
    div.style.top = y + 'px'; 
}

function StopAudio(key) {
    audioInstances[key].pause()
    audioInstances[key] = null;
}

function PlayAudio(key, loop) {
    if (audioInstances[key]) {
        audioInstances[key].pause();
        audioInstances[key].currentTime = 0
        audioInstances[key].play();
    }
    else {
        var audio = new Audio("assets/audio/"+key+".mp3");
        audio.loop = loop;
        audio.volume = 1.0;
        audio.play();
        audioInstances[key] = audio;
    }
}

function StartWelding(wireIndex, direction) {
    if (currentWeld || wires[wireIndex - 1].wired) return;
    currentWeld = {
        index: wireIndex,
        direction: direction,
        color: wires[wireIndex - 1].color - 1
    };
    var element = $("#ams-nodes > div:nth-child("+wireIndex+")");
    var weldElement = $("#ams-nodes > div:nth-child("+wireIndex+") > div:nth-child(2)");
    PlayAudio("weld", true)

    $("body").css("cursor", "none");
    $("#ams-welding").css("display", "block");
    SetWeldPosition(mouse.x - 50, mouse.y - 50);
    $.post("https://pickle_electrician/welding", JSON.stringify({
        toggle: true
    }));
}

function StopWelding(index) {
    if (!currentWeld) return;
    var weld = currentWeld;
    currentWeld = null;
    var element = $("#ams-nodes > div:nth-child("+weld.index+")");
    var weldElement = $("#ams-nodes > div:nth-child("+weld.index+") > div:nth-child(2)");
    StopAudio("weld");
    $("body").css("cursor", "unset");
    $("#ams-welding").css("display", "none");

    $.post("https://pickle_electrician/welding", JSON.stringify({
        toggle: false
    }));
    
    if (weld.direction == index) { // Success
        $(weldElement).css("background", COLORS[weld.color].active);
        wires[weld.index - 1].wired = true;
        PlayAudio("connected");
        CheckGame();
    }
    else { // Fail
        $(weldElement).css("background", COLORS[weld.color].inactive);
        wires[weld.index - 1].wired = false;
        PlayAudio("error");
        currentGame.attemptsLeft -= 1;
        CheckFailGame();
    }
}

function WireEvents() {
    $("#ams-nodes > div > div:nth-child(1)").mousedown(function(){ // Top to Bottom
        StartWelding($(this).parent().index() + 1, 0);
    });
    $("#ams-nodes > div > div:nth-child(3)").mousedown(function(){ // Bottom to Top
        StartWelding($(this).parent().index() + 1, 1);
    });
    $("#ams-nodes > div > div:nth-child(1)").mouseup(function(){ // Top to Bottom
        StopWelding(1);
    });
    $("#ams-nodes > div > div:nth-child(3)").mouseup(function(){ // Bottom to Top
        StopWelding(0);
    });
}

function CreateWires(wireCount, wireWidth) {
    var _wires = [];
    var html = "";
    var colorIndex = 0;
    var size = wireWidth;
    for (var i=0; i<wireCount; i++) {
        var wireHtml = `
        <div>
            <div style="width: {SIZE}; background: {COLOR_1};"></div>
            <div style="width: {SIZE}; background: {COLOR_2};"></div>
            <div style="width: {SIZE}; background: {COLOR_1};"></div>
        </div>
        `;
        if (colorIndex >= COLORS.length) {
            colorIndex = 0;
        }
        var color = COLORS[colorIndex];
        wireHtml = wireHtml.replaceAll("{COLOR_1}", color.active);
        wireHtml = wireHtml.replaceAll("{COLOR_2}", color.inactive);
        wireHtml = wireHtml.replaceAll("{SIZE}", size + "vw");
        html += wireHtml;
        colorIndex += 1;
        _wires[i] = {
            size: size,
            color: colorIndex,
            wired: false
        }
    }
    wires = _wires;
    $("#ams-nodes").html(html);
    WireEvents();
}

function CheckGame() {
    var missingWire;
    for (var i=0; i<wires.length; i++) {
        if (!wires[i].wired) {
            missingWire = i;
            break;
        }
    }
    if (missingWire != null) return;
    EndGame(true);
}

function CheckFailGame() {
    if (currentGame.attemptsLeft > 0) return;
    EndGame(false);
}

function EndGame(success, cancelCallback) {
    if (!currentGame) return;
    if (currentTimerLoop) {
        clearInterval(currentTimerLoop);
    }
    var cb = currentGame.cb;
    currentTimerLoop = null;
    currentTimer = null;
    currentGame = null;
    $("#app-minigame").fadeOut(1000, ()=>{
        SetDoor(false, function() {
            $("#ams-nodes").html("");
        });
    });
    if (!cb || cancelCallback) return;
    cb(success);
}

function DisplayInt(float) {
    var floor = Math.floor(float)
    if (floor < 10) {
        floor = "0" + floor;
    }
    return floor;
}

function GetTimerDisplay() {
    var minutes = Math.floor(currentTimer / 60);
    var seconds = currentTimer - minutes * 60;
    if (minutes < 0) {
        return `<span style="color: red">00:00</span>`;
    }
    return (DisplayInt(minutes) + ":" + DisplayInt(seconds) )
}

function StartTimer(seconds) {
    if (currentTimer) return;
    currentGame.started = true;
    currentTimer = seconds
    $("#am-timer").html(GetTimerDisplay());
    currentTimerLoop = setInterval(() => {
        PlayAudio("tick");
        var display = GetTimerDisplay();
        currentTimer -= 1;
        if (currentTimer <= 0) {
            currentTimer = 0;
            $("#am-timer").html(`<span style="color: red">${display}</span>`);
            EndGame(false)
        }
        else if (currentTimer < 10) {
            $("#am-timer").html(`<span style="color: red">${display}</span>`);
        }
        else {
            $("#am-timer").html(display);
        }
    }, 1000);
} 

function StartGame(settings, cb) {
    if (currentGame) return;
    currentGame = settings;
    currentGame.attemptsLeft = (settings.maxWeldFails ? settings.maxWeldFails : 3);
    currentGame.started = false;
    currentGame.cb = cb;
    currentGame.pending = true;
    setTimeout(() => {
        currentGame.pending = false;
    }, 1000);
    $("#am-timer").html("");
    $("#app-minigame").fadeIn(1000);
    CreateWires(settings.wireCount, settings.wireWidth)
}

function OnGameCompleted(success) {
    hEvent("endGame", {success: success}, (response) => {
    })
}

$(document).ready(() => {
    $("#am-overlay").on("click", function(ev) {
        if (!currentGame || currentGame.started || currentGame.pending) return;
        StartTimer(currentGame.time)
        SetDoor(!doorStatus)
    });
});

document.addEventListener('mousemove', function(e) {
    mouse.x = e.clientX;
    mouse.y = e.clientY
    
    if (!currentWeld) return;

    var x = mouse.x;
    var y = mouse.y;

    var index = currentWeld.index;

    var weldElement = $("#ams-nodes > div:nth-child("+index+") > div:nth-child(2)");
    var startElement = $("#ams-nodes > div:nth-child("+index+") > div:nth-child(1)");
    var endElement = $("#ams-nodes > div:nth-child("+index+") > div:nth-child(3)");

    var elemRect = $(weldElement)[0].getBoundingClientRect();
    var startRect = $(startElement)[0].getBoundingClientRect();
    var endRect = $(endElement)[0].getBoundingClientRect();

    var min = {x: elemRect.x, y: startRect.y};
    var max = {x: elemRect.x + (elemRect.width), y: endRect.y + (endRect.height)};
    
    if ((x + 1 < min.x || x - 1 > max.x) || (y + 1 < min.y || y - 1 > max.y)) { 
        StopWelding();
    }

    SetWeldPosition(x - 50, y - 50)
});

document.addEventListener('mouseup', function(ev) {
    if (!currentWeld) return;
    setTimeout(() => {
        if (!currentWeld) return;
        StopWelding();
    }, 100);
});

window.addEventListener('message', function(ev) {
    const data = ev.data;
    const info = data.args[0];
    if (data.name == "startGame") {
        StartGame(info, OnGameCompleted);
    }
    else if (data.name == "endGame") {
        EndGame(false, true);
    }
})

let str = "";

window.addEventListener("load", function() {
    document.getElementById("copyText").addEventListener("click", function() {
        navigator.clipboard.writeText(str);
        hEvent("disableInput", {}, (response) => {
        })
    });
});

window.addEventListener("message", function (event) {
    const data = event.data;
    if (data.name === "CopyTextToClipboard") {
        const text = data.args[0];
        console.log("Copying text to clipboard: ", text);
        str = text;        
    } else if (data.name === "setInteractText") {
        const info = data.args[0];
        const text = info.text;
        const id = info.id;
        const element = document.getElementById("text-" + id);
        if (element) {
            element.innerText = text;
        }
        else {
            const div = document.createElement("div");
            div.id = "text-" + id;
            div.className = "interactText";
            div.textContent = text;
            document.body.appendChild(div);
        }
    } else if (data.name === "hideInteractText") {
        const info = data.args[0];
        const id = info.id;
        const element = document.getElementById("text-" + id);
        if (element) {
            element.remove();
        }
    } else if (data.name === "updateInteractTextPosition") {
        const info = data.args[0];
        const position = {
            top: info.top,
            left: info.left,
            scale: info.scale,
        }
        const id = info.id;
        const interactText = document.getElementById("text-" + id);
        if (!interactText) {
            return;
        }
        if ((position.top <= 0 && position.left <= 0) || position.scale <= 0) {
            interactText.style.display = "none";
            return;
        }
        interactText.style.display = "block";
        // Get native (unscaled) width and height for centering
        const scale = position.scale || 1;
        const width = interactText.offsetWidth;
        const height = interactText.offsetHeight;
        // Position the center of the text at the desired coordinates, scaling about its center
        interactText.style.top = (position.top - (height / 2)) + "px";
        interactText.style.left = (position.left - (width / 2)) + "px";
        // Use CSS transform-origin to center scaling, then apply scale
        interactText.style.transformOrigin = "center center";
        interactText.style.transform = `scale(${scale})`;
    }
});