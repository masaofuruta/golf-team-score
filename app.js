/* =========================================================================
 * ゴルフ チーム戦スコア計算 — ローカル Web アプリ
 *
 * ルール:
 *   - プレイヤーごとに グロス（合計打数）と ハンディ を入力
 *   - ネット = グロス − ハンディ
 *   - チームの グロス合計 / ネット合計 を集計
 *   - グロス合計の順位 と ネット合計の順位 を足した「合算」が
 *     最小のチームが総合優勝（同点はネット合計が少ない方が上位）
 *
 * データは通信せず、この端末の localStorage にのみ保存します。
 * ======================================================================= */

(function () {
  "use strict";

  var STORAGE_KEY = "golfTeamMatch.v1";

  // ---- アプリの状態 ----------------------------------------------------
  var state = {
    eventName: "",
    eventDate: "",
    courseName: "",
    netMode: "handicap", // "handicap": ネット=グロス−ハンディ / "direct": ネットを直接入力
    teams: [], // { id, name, players: [ { id, name, handicap, gross, netManual } ] }
  };

  var seq = 1;
  function nextId() {
    return "id" + seq++ + "_" + Math.floor(Math.random() * 1e6);
  }

  // ---- 永続化 ----------------------------------------------------------
  function save() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
      setStatus("自動保存済み " + new Date().toLocaleTimeString("ja-JP"));
    } catch (e) {
      setStatus("保存に失敗しました");
    }
  }

  function load() {
    try {
      var raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return false;
      var data = JSON.parse(raw);
      if (!data || !Array.isArray(data.teams)) return false;
      state = normalize(data);
      // seq がプレイヤー/チームID と衝突しないよう大きめに
      seq = Math.max(seq, state.teams.length * 50 + 100);
      return true;
    } catch (e) {
      return false;
    }
  }

  // 読み込んだデータを安全な形に整える
  function normalize(data) {
    var s = {
      eventName: str(data.eventName),
      eventDate: str(data.eventDate),
      courseName: str(data.courseName),
      netMode: data.netMode === "direct" ? "direct" : "handicap",
      teams: [],
    };
    (data.teams || []).forEach(function (t) {
      var team = {
        id: t && t.id ? String(t.id) : nextId(),
        name: str(t && t.name),
        players: [],
      };
      ((t && t.players) || []).forEach(function (p) {
        team.players.push({
          id: p && p.id ? String(p.id) : nextId(),
          name: str(p && p.name),
          handicap: numOrNull(p && p.handicap),
          gross: numOrNull(p && p.gross),
          netManual: numOrNull(p && p.netManual),
        });
      });
      s.teams.push(team);
    });
    return s;
  }

  function str(v) {
    return v == null ? "" : String(v);
  }
  function numOrNull(v) {
    if (v === "" || v == null) return null;
    var n = Number(v);
    return isFinite(n) ? n : null;
  }

  // プレイヤーのネット値を現在のモードに応じて返す（未確定なら null）
  function playerNet(p) {
    if (state.netMode === "direct") {
      return p.netManual; // 直接入力（未入力は null）
    }
    if (p.gross == null) return null;
    var hc = p.handicap == null ? 0 : p.handicap;
    return p.gross - hc;
  }

  // ---- 集計ロジック ----------------------------------------------------
  // 各チームの合計と、グロス/ネット/総合の順位を計算して返す
  function computeStandings() {
    var rows = state.teams.map(function (team) {
      var grossTotal = 0;
      var netTotal = 0;
      var counted = 0;
      team.players.forEach(function (p) {
        if (p.gross != null) grossTotal += p.gross;
        var net = playerNet(p);
        if (net != null) netTotal += net;
        // グロスまたはネットのいずれかが入力されていれば集計対象
        if (p.gross != null || net != null) counted += 1;
      });
      return {
        team: team,
        counted: counted,
        grossTotal: grossTotal,
        netTotal: netTotal,
      };
    });

    // グロスの入力が1人でもあるチームだけをランキング対象にする
    var ranked = rows.filter(function (r) {
      return r.counted > 0;
    });

    assignRank(ranked, "grossTotal", "grossRank");
    assignRank(ranked, "netTotal", "netRank");

    ranked.forEach(function (r) {
      r.combined = r.grossRank + r.netRank;
    });

    // 総合順位: 合算(combined)の昇順、同点はネット合計→グロス合計で決定
    var sorted = ranked.slice().sort(function (a, b) {
      if (a.combined !== b.combined) return a.combined - b.combined;
      if (a.netTotal !== b.netTotal) return a.netTotal - b.netTotal;
      return a.grossTotal - b.grossTotal;
    });
    for (var i = 0; i < sorted.length; i++) {
      sorted[i].overallRank = i + 1;
    }

    return { sorted: sorted, unrankedCount: rows.length - ranked.length };
  }

  // 標準的な競技順位付け（同値は同順位・次は飛ばす: 1,2,2,4 …）
  function assignRank(list, key, rankKey) {
    var arr = list.slice().sort(function (a, b) {
      return a[key] - b[key];
    });
    for (var i = 0; i < arr.length; i++) {
      if (i > 0 && arr[i][key] === arr[i - 1][key]) {
        arr[i][rankKey] = arr[i - 1][rankKey];
      } else {
        arr[i][rankKey] = i + 1;
      }
    }
  }

  // ---- 描画: チーム編集 ------------------------------------------------
  function renderTeams() {
    var container = document.getElementById("teamsContainer");
    container.innerHTML = "";

    if (state.teams.length === 0) {
      var empty = document.createElement("p");
      empty.className = "empty";
      empty.textContent = "まだチームがありません。「＋ チームを追加」から始めてください。";
      container.appendChild(empty);
      return;
    }

    state.teams.forEach(function (team) {
      container.appendChild(buildTeamEl(team));
    });
  }

  function buildTeamEl(team) {
    var wrap = el("div", "team");

    // ヘッダー（チーム名 + 合計 + 削除）
    var head = el("div", "team-head");
    var nameInput = document.createElement("input");
    nameInput.type = "text";
    nameInput.className = "team-name";
    nameInput.placeholder = "チーム名";
    nameInput.value = team.name;
    nameInput.addEventListener("input", function () {
      team.name = nameInput.value;
      save();
      renderResults();
    });

    var totals = el("span", "team-totals");
    totals.textContent = teamTotalsText(team);

    var delTeam = document.createElement("button");
    delTeam.className = "btn danger small";
    delTeam.textContent = "チーム削除";
    delTeam.addEventListener("click", function () {
      if (confirm("「" + (team.name || "無名チーム") + "」を削除しますか？")) {
        state.teams = state.teams.filter(function (t) {
          return t.id !== team.id;
        });
        save();
        renderAll();
      }
    });

    head.appendChild(nameInput);
    head.appendChild(totals);
    head.appendChild(delTeam);
    wrap.appendChild(head);

    // プレイヤー表
    var scroll = el("div", "table-scroll");
    var table = document.createElement("table");
    table.className = "players-table";
    var middleHeader =
      state.netMode === "direct"
        ? "<th>グロス</th><th>ネット</th>"
        : "<th>ハンディ</th><th>グロス</th><th>ネット</th>";
    table.innerHTML =
      "<thead><tr>" +
      "<th class='name-cell'>プレイヤー</th>" +
      middleHeader +
      "<th></th>" +
      "</tr></thead>";
    var tbody = document.createElement("tbody");

    team.players.forEach(function (p) {
      tbody.appendChild(buildPlayerRow(team, p));
    });
    table.appendChild(tbody);
    scroll.appendChild(table);
    wrap.appendChild(scroll);

    // フッター（プレイヤー追加）
    var actions = el("div", "team-actions");
    var addP = document.createElement("button");
    addP.className = "btn small";
    addP.textContent = "＋ プレイヤーを追加";
    addP.addEventListener("click", function () {
      team.players.push({ id: nextId(), name: "", handicap: null, gross: null, netManual: null });
      save();
      renderAll();
    });
    actions.appendChild(addP);
    wrap.appendChild(actions);

    return wrap;
  }

  function buildPlayerRow(team, player) {
    var tr = document.createElement("tr");

    // 名前
    var nameTd = el("td", "name-cell");
    var name = document.createElement("input");
    name.type = "text";
    name.className = "player-name";
    name.placeholder = "名前";
    name.value = player.name;
    name.addEventListener("input", function () {
      player.name = name.value;
      save();
    });
    nameTd.appendChild(name);
    tr.appendChild(nameTd);

    // グロス（両モード共通）
    var grossTd = document.createElement("td");
    var gross = numberInput(player.gross);
    gross.min = "0";
    gross.addEventListener("input", function () {
      player.gross = numOrNull(gross.value);
      onScoreChange(team, tr, player);
    });
    grossTd.appendChild(gross);

    if (state.netMode === "direct") {
      // グロス → ネット直接入力
      tr.appendChild(grossTd);
      var netInTd = document.createElement("td");
      var netIn = numberInput(player.netManual);
      netIn.min = "0";
      netIn.addEventListener("input", function () {
        player.netManual = numOrNull(netIn.value);
        onScoreChange(team, tr, player);
      });
      netInTd.appendChild(netIn);
      tr.appendChild(netInTd);
    } else {
      // ハンディ → グロス → ネット（自動計算表示）
      var hcTd = document.createElement("td");
      var hc = numberInput(player.handicap);
      hc.step = "any";
      hc.addEventListener("input", function () {
        player.handicap = numOrNull(hc.value);
        onScoreChange(team, tr, player);
      });
      hcTd.appendChild(hc);
      tr.appendChild(hcTd);
      tr.appendChild(grossTd);

      var netTd = el("td", "net-cell");
      netTd.textContent = netText(player);
      tr.appendChild(netTd);
    }

    // 削除
    var delTd = document.createElement("td");
    var del = document.createElement("button");
    del.className = "btn icon danger small";
    del.textContent = "✕";
    del.title = "このプレイヤーを削除";
    del.addEventListener("click", function () {
      team.players = team.players.filter(function (p) {
        return p.id !== player.id;
      });
      save();
      renderAll();
    });
    delTd.appendChild(del);
    tr.appendChild(delTd);
    return tr;
  }

  // スコア/ハンディ変更時: ネット表示とチーム合計・結果だけ更新（再描画で入力欄が飛ばないように）
  function onScoreChange(team, tr, player) {
    var netTd = tr.querySelector(".net-cell");
    if (netTd) netTd.textContent = netText(player);
    updateTeamTotals(team);
    save();
    renderResults();
  }

  function teamTotalsText(team) {
    var grossT = 0,
      netT = 0;
    team.players.forEach(function (p) {
      if (p.gross != null) grossT += p.gross;
      var net = playerNet(p);
      if (net != null) netT += net;
    });
    return "グロス " + grossT + " / ネット " + netT;
  }

  function updateTeamTotals(team) {
    // 全チーム再描画は避け、対応する totals 要素を探して更新
    var heads = document.querySelectorAll(".team");
    var idx = state.teams.indexOf(team);
    if (idx >= 0 && heads[idx]) {
      var totals = heads[idx].querySelector(".team-totals");
      if (totals) totals.textContent = teamTotalsText(team);
    }
  }

  function netText(player) {
    var net = playerNet(player);
    return net == null ? "—" : String(net);
  }

  // ---- 描画: 結果 ------------------------------------------------------
  function renderResults() {
    var container = document.getElementById("resultsContainer");
    container.innerHTML = "";

    var result = computeStandings();
    var sorted = result.sorted;

    if (sorted.length === 0) {
      var empty = el("p", "empty");
      empty.textContent = "グロスを入力すると、ここに順位が表示されます。";
      container.appendChild(empty);
      return;
    }

    var scroll = el("div", "table-scroll");
    var table = document.createElement("table");
    table.className = "results-table";
    table.innerHTML =
      "<thead><tr>" +
      "<th>総合</th>" +
      "<th>チーム</th>" +
      "<th>グロス合計</th>" +
      "<th>グロス順位</th>" +
      "<th>ネット合計</th>" +
      "<th>ネット順位</th>" +
      "<th>合算</th>" +
      "</tr></thead>";
    var tbody = document.createElement("tbody");

    sorted.forEach(function (r) {
      var tr = document.createElement("tr");
      if (r.overallRank === 1) tr.className = "champion";

      var name = r.team.name || "無名チーム";
      var champBadge = r.overallRank === 1 ? "<span class='badge'>優勝</span>" : "";

      tr.innerHTML =
        "<td>" + r.overallRank + "</td>" +
        "<td class='team-cell'>" + escapeHtml(name) + champBadge + "</td>" +
        "<td>" + r.grossTotal + "</td>" +
        "<td>" + r.grossRank + "</td>" +
        "<td>" + r.netTotal + "</td>" +
        "<td>" + r.netRank + "</td>" +
        "<td class='combined-cell'>" + r.combined + "</td>";
      tbody.appendChild(tr);
    });

    table.appendChild(tbody);
    scroll.appendChild(table);
    container.appendChild(scroll);

    if (result.unrankedCount > 0) {
      var note = el("p", "hint");
      note.textContent =
        "※ グロス未入力のチームが " + result.unrankedCount + " チームあり、集計から除外しています。";
      container.appendChild(note);
    }
  }

  // ---- 描画: 大会情報 --------------------------------------------------
  function renderEventFields() {
    document.getElementById("eventName").value = state.eventName;
    document.getElementById("eventDate").value = state.eventDate;
    document.getElementById("courseName").value = state.courseName;
  }

  function renderNetMode() {
    var radios = document.getElementsByName("netModeRadio");
    for (var i = 0; i < radios.length; i++) {
      radios[i].checked = radios[i].value === state.netMode;
    }
    var hint = document.getElementById("teamsHint");
    if (hint) {
      hint.textContent =
        state.netMode === "direct"
          ? "各プレイヤーの「グロス（合計打数）」と「ネット」を直接入力してください。"
          : "各プレイヤーの「ハンディ」と「グロス（合計打数）」を入力してください。ネット＝グロス−ハンディで自動計算します。";
    }
  }

  function renderAll() {
    renderEventFields();
    renderNetMode();
    renderTeams();
    renderResults();
  }

  // ---- ヘルパー --------------------------------------------------------
  function el(tag, cls) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    return e;
  }
  function numberInput(value) {
    var i = document.createElement("input");
    i.type = "number";
    i.inputMode = "numeric";
    i.value = value == null ? "" : String(value);
    return i;
  }
  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }
  function setStatus(text) {
    var s = document.getElementById("saveStatus");
    if (s) s.textContent = "自動保存: " + text;
  }

  // ---- イベント配線 ----------------------------------------------------
  function wireUp() {
    document.getElementById("eventName").addEventListener("input", function (e) {
      state.eventName = e.target.value;
      save();
    });
    document.getElementById("eventDate").addEventListener("input", function (e) {
      state.eventDate = e.target.value;
      save();
    });
    document.getElementById("courseName").addEventListener("input", function (e) {
      state.courseName = e.target.value;
      save();
    });

    var netRadios = document.getElementsByName("netModeRadio");
    for (var i = 0; i < netRadios.length; i++) {
      netRadios[i].addEventListener("change", function (e) {
        if (!e.target.checked) return;
        state.netMode = e.target.value === "direct" ? "direct" : "handicap";
        save();
        renderAll();
      });
    }

    document.getElementById("addTeamBtn").addEventListener("click", function () {
      state.teams.push({
        id: nextId(),
        name: "チーム" + (state.teams.length + 1),
        players: [{ id: nextId(), name: "", handicap: null, gross: null, netManual: null }],
      });
      save();
      renderAll();
    });

    document.getElementById("sampleBtn").addEventListener("click", function () {
      if (state.teams.length > 0 && !confirm("現在のデータをサンプルで置き換えますか？")) return;
      state = sampleData();
      save();
      renderAll();
    });

    document.getElementById("resetBtn").addEventListener("click", function () {
      if (!confirm("すべてのデータを消去します。よろしいですか？")) return;
      state = { eventName: "", eventDate: "", courseName: "", netMode: state.netMode, teams: [] };
      save();
      renderAll();
    });

    document.getElementById("exportBtn").addEventListener("click", exportJson);
    document.getElementById("importBtn").addEventListener("click", function () {
      document.getElementById("importFile").click();
    });
    document.getElementById("importFile").addEventListener("change", importJson);
  }

  function exportJson() {
    var blob = new Blob([JSON.stringify(state, null, 2)], { type: "application/json" });
    var url = URL.createObjectURL(blob);
    var a = document.createElement("a");
    var base = state.eventName ? state.eventName.replace(/[^\w\-一-龠ぁ-んァ-ヶ]/g, "_") : "golf_team_match";
    a.href = url;
    a.download = base + ".json";
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  function importJson(e) {
    var file = e.target.files && e.target.files[0];
    if (!file) return;
    var reader = new FileReader();
    reader.onload = function () {
      try {
        var data = JSON.parse(reader.result);
        state = normalize(data);
        seq = Math.max(seq, state.teams.length * 50 + 100);
        save();
        renderAll();
        alert("読み込みました。");
      } catch (err) {
        alert("読み込みに失敗しました。JSON形式を確認してください。");
      }
    };
    reader.readAsText(file);
    e.target.value = ""; // 同じファイルを再度選べるように
  }

  function sampleData() {
    function pl(name, hc, gross) {
      return { id: nextId(), name: name, handicap: hc, gross: gross, netManual: gross - hc };
    }
    return {
      eventName: "サンプルコンペ",
      eventDate: "",
      courseName: "サンプルカントリークラブ",
      netMode: state.netMode,
      teams: [
        {
          id: nextId(),
          name: "レッドチーム",
          players: [pl("田中", 12, 92), pl("鈴木", 20, 105), pl("佐藤", 8, 85)],
        },
        {
          id: nextId(),
          name: "ブルーチーム",
          players: [pl("山本", 15, 98), pl("中村", 6, 82), pl("小林", 24, 110)],
        },
        {
          id: nextId(),
          name: "グリーンチーム",
          players: [pl("加藤", 10, 90), pl("吉田", 18, 101), pl("山田", 14, 95)],
        },
      ],
    };
  }

  // ---- 起動 ------------------------------------------------------------
  function init() {
    var had = load();
    wireUp();
    renderAll();
    setStatus(had ? "前回のデータを読み込みました" : "準備完了");
  }

  document.addEventListener("DOMContentLoaded", init);
})();
