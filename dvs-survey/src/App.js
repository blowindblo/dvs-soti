// src/App.js
import React, { useState, useEffect, useRef } from "react";
import * as d3 from "d3";
import "./App.css";

function App() {
  const svgRef = useRef(null);
  const sampleSizeRef = useRef(null);
  const tools = new Set([
    "Excel",
    "Tableau",
    "R",
    "Illustrator",
    "D3",
    "ggplot2",
    "Python",
    "PowerBI",
    "Flourish",
    "Datawrapper",
  ]);
  const [toolsSelected, setTools] = useState(tools);

  let typeMap = {
    Community: 1,
    "Social Network": 2,
    Magazine: 3,
    Person: 4,
    Blog: 5,
    Organisation: 6,
  };

  // Node colour
  // var colourScale = d3.scaleOrdinal().domain([1, 6]).range(colour.scale);
  var colourScale = {
    1: "#1abc9c",
    2: "#3498db",
    3: "#9b59b6",
    4: "#e67e22",
    5: "#e74c3c",
    6: "#f1c40f",
  };
  // dimensions
  const margin = { top: 40, right: 30, bottom: 40, left: 30 },
    width = 1000 - margin.left - margin.right,
    height = 500 - margin.top - margin.bottom;
  let sampleSize = 0;

  const getData = async () => {
    let files = [
      "https://raw.githubusercontent.com/blowindblo/dvs-soti/main/dvs-survey/public/data/dvs_survey_analysis_id.csv",
      "https://raw.githubusercontent.com/blowindblo/dvs-soti/main/dvs-survey/public/data/dvs_nodes.csv",
    ];
    let promises = files.map((url) => d3.csv(url, d3.autoType));

    const datasets = await Promise.all(promises);

    return datasets;
  };

  const transformData = async (datasets) => {
    const data = {
      nodes: [],
      links: [],
    };

    // Function to calculate sum of specified keys for an object
    const calculateSum = (obj) => {
      return Array.from(toolsSelected).reduce((acc, key) => {
        // Check if key exists and has a valid value
        if (obj.hasOwnProperty(key) && !isNaN(obj[key])) {
          return acc + obj[key];
        } else {
          return acc; // Ignore invalid keys or values
        }
      }, 0);
    };

    // Calculate sum for each object in the array and add sumTools key
    const rawData = await datasets[0]
      .map((obj) => ({
        ...obj,
        sumTools: calculateSum(obj),
      }))
      .filter((obj) => obj.sumTools !== 0);

    // Mapping inspir type to numbers
    let prevID;
    let inspirArr = [];

    for (let i = 0; i < rawData.length; i++) {
      let currID = rawData[i].ID;
      let newInspir = rawData[i].inspirID;

      // Populating nodes data
      const nodeMatch = data.nodes.find((x) => x.inspirID === newInspir);

      if (nodeMatch === undefined) {
        if (typeMap[rawData[i].type] === undefined) {
          console.log(rawData[i].type);
        }
        data.nodes.push({
          inspirID: newInspir,
          inspir: rawData[i].inspir,
          type: typeMap[rawData[i].type],
          count: 1,
        });
      } else {
        nodeMatch.count += 1;
      }

      // Populating links data
      if ((currID !== prevID) | (i === 0)) {
        inspirArr = [];
        inspirArr.push(newInspir);
        sampleSize += 1;
      }

      // If same respondent
      if (currID === prevID) {
        // Loop through respondent's inspirArr and add links
        for (const oldInspir of inspirArr) {
          if (oldInspir === newInspir) {
            console.log("Error: Repeat");
            console.log(i, oldInspir);
          }

          // Ensure source is the lower value and target is the higher value
          let source, target;
          if (oldInspir < newInspir) {
            source = oldInspir;
            target = newInspir;
          } else {
            source = newInspir;
            target = oldInspir;
          }

          // Check for existing link
          const linkMatch = data.links.find(
            (x) => (x.source === source) & (x.target === target)
          );

          if (linkMatch === undefined) {
            // Add new link
            data.links.push({
              source: source,
              target: target,
              count: 1,
            });
          } else {
            // Increment
            linkMatch.count += 1;
          }
        }
        inspirArr.push(newInspir);
      }
      prevID = currID;
    }

    // Sort nodes by popularity
    data.nodes.sort((a, b) => b.count - a.count);

    return data;
  };

  const drawGraph = async (data) => {
    console.log(data);

    // create link reference
    let linkedByIndex = {};

    data.links.forEach((d) => {
      linkedByIndex[`${d.source},${d.target}`] = true;
    });

    const opacity = {
      activeLink: 0.9,
      inactiveLink: 0,
      activeNode: 1,
      inactiveNode: 0.1,
      neighbourNode: 1,
      toolTip: 0.9,
    };

    const strokeWidth = {
      activeMainNode: "3px",
      otherNode: "1px",
      // activeLink: "1px",
    };

    const colour = {
      // scale: ["gold", "blue", "green", "yellow", "grey", "orange"],
      link: "#5f6b76",
      selectedNodeStroke: "#2c3e50",
      unselectedNodeStroke: "#5f6b76",
      // selectedNodeFill: ""
    };

    const transitionTime = 200;
    const isConnectedAsSource = (a, b) => linkedByIndex[`${a},${b}`];
    const isConnectedAsTarget = (a, b) => linkedByIndex[`${b},${a}`];
    const isConnected = (a, b) =>
      isConnectedAsTarget(a, b) || isConnectedAsSource(a, b) || a === b;
    const isEqual = (a, b) => a === b;

    // Getting neighbours of nodes
    const neighbours = [];
    data.nodes.forEach((n1) => {
      let entry = n1;
      entry.neighbours = [];
      data.nodes.forEach((n2) => {
        if (isConnected(n1.inspirID, n2.inspirID)) {
          entry.neighbours.push({
            inspir: n2.inspir,
            type: n2.type,
            count: n2.count,
          });
        }
      });
      entry.neighbours.sort((a, b) => b.count - a.count);
      neighbours.push(entry);
    });

    // Node size
    const nodeRadius = (d) => {
      return d.count / 3 + 7;
    };

    // append the svg object to the body of the page
    const svg = d3
      .select(svgRef.current)
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom);

    const top5_inspir = data.nodes.slice(0, 5).map((d) => d.inspir);
    const top5_count = data.nodes.slice(0, 5).map((d) => d.count);

    d3.select(sampleSizeRef.current).html(
      `<strong>Sample size: </strong>${sampleSize}<br> <strong>Top 5 influences: </strong>${top5_inspir.join(
        ", "
      )}`
    );

    const everything = svg.selectAll("*");
    everything.remove();

    const container = svg
      .append("g")
      .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

    // Tooltips
    var tooltip = d3
      .select(".App")
      .append("div")
      .classed("tooltip tooltip-primary rounded-md px-2 text-black	", true)
      .style("position", "absolute")
      .style("z-index", "10")
      .style("opacity", opacity.toolTip)
      .style("background-color", "white")
      .style("visibility", "hidden")
      .text("simple");

    var inspirList = d3
      .select(".inspirContainer")
      .classed("flex justify-evenly mt-0	overflow-auto", true)
      .style("position", "relative")
      .selectAll(".neighbours") // Select
      .data([1, 2, 3, 4, 5, 6])
      .join("div")
      .classed("neighbours", true)
      .style("width", (d) => width / 6)
      .style("visibility", "hidden")
      .text("simple");

    const simulation = d3
      .forceSimulation(data.nodes) // apply the simulation to our array of nodes
      // Force #1: links between nodes
      .force(
        "link",
        d3
          .forceLink(data.links)
          .id((d) => d.inspirID)
          .strength(0.05)
      )

      // Force #2: avoid node overlaps
      .force(
        "collide",
        d3
          .forceCollide()
          .radius((d) => nodeRadius(d) + 2)
          .iterations(5)
      )
      // Force #3: attraction or repulsion between nodes
      .force("charge", d3.forceManyBody(-1))

      // Force #4: nodes are attracted by the center of the chart area
      .force("center", d3.forceCenter(width / 2, height / 2))
      .force("y", d3.forceY(height / 2).strength(0.1))
      .force(
        "x",
        d3
          .forceX((d) => {
            return (width / 6) * d.type;
          })
          .strength(5)
      );

    let isClicked = false;

    // Initialize the links
    const link = container
      .selectAll("line")
      .data(data.links.filter((d) => d.count > 0))
      .join("line")
      .style("stroke", colour.link)
      .style("stroke-opacity", opacity.inactiveLink)
      .lower();

    // Initialize the nodes
    const nodeContainer = container
      .append("g")
      .classed("nodes", true)
      .selectAll("circle")
      .data(data.nodes);

    const node = nodeContainer
      // .join("g")
      .join("circle")
      .attr("r", (d) => nodeRadius(d))
      .style("fill", function (d) {
        return colourScale[d.type];
      })
      .style("stroke", colour.unselectedNodeStroke)
      .style("stroke-width", strokeWidth.inactiveNode)
      .raise()
      .on("mouseover", function (event, d) {
        tooltip
          .html(`<strong>${d.inspir}</strong><br> ${d.count}`)
          // .text(d.inspir)
          .attr("x", d.x + 1) // Offset the text a bit to the right of the circle
          .attr("y", d.y + 1) // Offset the text a bit above the circle
          .style("left", event.pageX + "px")
          .style("top", event.pageX + "py")
          .style("visibility", "visible");
        if (isClicked) return;

        inspirList.each(function (datum, i) {
          const neighbourNames = d.neighbours
            .filter((n) => n.type === datum)
            .map((neighbour) => neighbour.inspir);

          if (neighbourNames.length > 0) {
            const neighbourHtml = neighbourNames
              .map((name) =>
                name === d.inspir ? `<strong>${name}</strong>` : name
              )
              .join("<br><hr>");
            d3.select(this)
              .classed("mx-1", true)
              .html(`<hr>${neighbourHtml}<hr>`)
              .style("visibility", "visible");
          }
        });

        node
          .transition(transitionTime)
          .style("opacity", (n) =>
            isEqual(n.inspirID, d.inspirID)
              ? opacity.activeNode
              : isConnected(n.inspirID, d.inspirID)
              ? opacity.neighbourNode
              : opacity.inactiveNode
          )
          .style("stroke-width", (n) => {
            return isEqual(n.inspirID, d.inspirID)
              ? strokeWidth.activeMainNode
              : strokeWidth.otherNode;
          });

        link.transition(transitionTime).style("stroke-opacity", (o) => {
          return o.source.inspirID === d.inspirID ||
            o.target.inspirID === d.inspirID
            ? opacity.activeLink
            : opacity.inactiveLink;
        });
      })
      .on("mousemove", function (event, d) {
        tooltip
          .style("left", event.pageX + 10 + "px")
          .style("top", event.pageY + 10 + "px");
      })
      .on("mouseout", function (event, d) {
        tooltip.style("visibility", "hidden");

        if (isClicked) return;
        inspirList.style("visibility", "hidden");

        node
          .transition(transitionTime)
          .style("opacity", opacity.activeNode)
          .style("stroke-width", strokeWidth.otherNode);
        link
          .transition(transitionTime)
          .style("stroke-opacity", opacity.inactiveLink);
      })
      .on("click", function (event, d) {
        isClicked = true;

        node
          .transition(transitionTime)
          .style("opacity", (n) => {
            return isConnected(n.inspirID, d.inspirID)
              ? opacity.activeNode
              : opacity.inactiveNode;
          })
          .style("stroke", (n) => {
            return isEqual(n.inspirID, d.inspirID)
              ? colour.selectedNodeStroke
              : colour.unselectedNodeStroke;
          })
          .style("stroke-width", (n) => {
            return isEqual(n.inspirID, d.inspirID)
              ? strokeWidth.activeMainNode
              : strokeWidth.otherNode;
          });
        inspirList.each(function (datum, i) {
          const neighbourNames = d.neighbours
            .filter((n) => n.type === datum)
            .map((neighbour) => neighbour.inspir);

          if (neighbourNames.length > 0) {
            const neighbourHtml = neighbourNames
              .map((name) =>
                name === d.inspir ? `<strong>${name}</strong>` : name
              )
              .join("<br><hr>");
            d3.select(this)
              .classed("mx-1", true)
              .html(`<hr>${neighbourHtml}<hr>`)
              .style("visibility", "visible");
          }
        });

        link.transition(transitionTime).style("stroke-opacity", (o) => {
          return o.source.inspirID === d.inspirID ||
            o.target.inspirID === d.inspirID
            ? opacity.activeLink
            : opacity.inactiveLink;
        });
        event.stopPropagation();
      });

    // Clicking on empty parts of the svg resets the graph
    svg.on("click", () => {
      console.log("click on svg");
      isClicked = false;
      inspirList.style("visibility", "hidden");

      node
        .transition(transitionTime)
        .style("opacity", opacity.activeNode)
        .style("stroke", colour.unselectedNodeStroke)
        .style("stroke-width", strokeWidth.otherNode);
      link
        .transition(transitionTime)
        .style("stroke-opacity", opacity.inactiveLink);
    });

    simulation.tick(50).on("tick", ticked);

    function ticked() {
      link
        .attr("x1", function (d) {
          return d.source.x;
        })
        .attr("y1", function (d) {
          return d.source.y;
        })
        .attr("x2", function (d) {
          return d.target.x;
        })
        .attr("y2", function (d) {
          return d.target.y;
        });

      node
        .attr("cx", function (d) {
          return d.x + 1;
        })
        .attr("cy", function (d) {
          return d.y - 1;
        });
    }
  };
  const checkTools = (x, y) => x.size === y.size;
  const checkTool = (d) => {
    console.log(toolsSelected.has(d));
    return toolsSelected.has(d);
  };

  useEffect(() => {
    const widthtest = svgRef.current?.offsetWidth;
    console.log(widthtest);
    getData()
      .then((d) => transformData(d))
      .then((d) => drawGraph(d))
      .then((d) => console.log(toolsSelected.size));
  }, [tools]);

  return (
    <div className="App h-screen ">
      <article class="">
        <header class="mx-32">
          <h1 class="mt-6 mb-4 text-4xl text-cyan-700 font-extrabold">
            Visualizing responses to: <br></br>
            <span class=" text-primary-content text-5xl">
              "Who do you find helpful for inspiration in data visualization?
              Feel free to list multiple influences."
            </span>
            <span class="text-primary-content text-base">
              {" "}
              <a
                href="https://www.datavisualizationsociety.org/"
                className="underline text-cyan-600 hover:text-slate-600"
              >
                Data Visualization Society
              </a>
              : SOTI Survey 2021
            </span>
          </h1>
          <p class=" text-xl italic ">
            Discover new sources of inspirations from others who use the same
            data tools or share the same influences as you!
          </p>
          <div className="my-4 mx-10 collapse collapse-arrow bg-base-200">
            <input type="checkbox" />
            <div className="collapse-title text-lg font-medium">
              Understanding the Visualization{" "}
              <span className="text-cyan-700 text-sm">(Click to expand!)</span>
            </div>
            <div className="collapse-content">
              <p className="description text-left mx-10">
                This interactive network graph depicts the sources of
                inspiration (or influences) for data visualization based on{" "}
                <a
                  href="https://www.datavisualizationsociety.org/"
                  className="underline text-cyan-600 hover:text-slate-600"
                >
                  Data Visualization Society
                </a>
                : State of the Industry Survey 2021. <br></br>Each node{" "}
                <span class=" h-5 w-5 bg-orange-400 border border-gray-600  rounded-full inline-block"></span>{" "}
                represents an influence and influences are clustered by{" "}
                <span className="badge badge-lg  font-bold badge-outline border-2">
                  category
                </span>
                , with node size representing popularity (i.e., the number of
                mentions). Connections between nodes show other influences
                mentioned by respondents who cited the selected influence.
                <div class="divider my-0.5"></div>
                <ul class="list-disc list-outside">
                  <li>
                    <strong>Hover</strong> over nodes to see detailed
                    information and mention counts, as well as connections to
                    other influences. influence.
                  </li>
                  <li>
                    <strong>Click</strong> a node to keep its information
                    visible while exploring other nodes. To deselect, click
                    another node or any empty space within the graph.
                  </li>
                  <li>
                    <strong>Filter</strong> the data using the row of toggle
                    buttons. These buttons represent the tools respondents use
                    to create visualizations, based on the question{" "}
                    <span class="italic font-bold">
                      "What technologies do you use often to visualize data?"
                    </span>
                    . Selecting a tool filters the data to include respondents
                    who use that tool. This is an inclusive filter, so selecting
                    multiple tools will show data for respondents who use any of
                    the selected tools (e.g., selecting 'R' and 'Python'
                    includes respondents using either or both tools).
                  </li>
                </ul>
                <div class="divider my-0.5"></div>
                Note: Influences mentioned only once are not included. The data
                is open-ended and cleaned using NLTK. Respondents who left the
                question blank were discarded.
              </p>
            </div>
          </div>
        </header>
        <div>
          Filter the data by selecting tools respondents use to create
          visualizations:
        </div>
        <div className="flex gap-x-8 justify-center my-6">
          <div>
            <input
              type="checkbox"
              className="btn btn-sm px-6 text-md	"
              aria-label="All"
              onChange={() =>
                tools.size !== toolsSelected.size
                  ? setTools(tools)
                  : setTools(new Set())
              }
              checked={checkTools(tools, toolsSelected)}
            />
          </div>
          <div className="join">
            {Array.from(tools).map(function (d, index) {
              return (
                <input
                  className="join-item btn btn-sm text-md	 	"
                  type="checkbox"
                  key={"option" + index}
                  onChange={() => {
                    const newTools = new Set(Array.from(toolsSelected)); // Create a new array with d added to toolsSelected
                    if (!toolsSelected.has(d)) {
                      newTools.add(d);
                    } else {
                      newTools.delete(d);
                    }
                    setTools(newTools);
                  }}
                  checked={checkTool(d)}
                  aria-label={d}
                />
              );
            })}
          </div>
        </div>
        <div ref={sampleSizeRef}></div>
      </article>
      <div className="graphContainer flex flex-col items-center justify-center ">
        <div className="flex justify-center sticky">
          <svg className="" ref={svgRef}></svg>
        </div>
        <div className="grid types  py-2" style={{ width: `${width}px` }}>
          {Array.from(
            Object.keys(typeMap).map(function (d, index) {
              return (
                <div key={index} className="flex justify-center items-center">
                  <div
                    className="badge badge-lg badge-outline font-bold	border-2	shadow-inner"
                    style={{
                      color: colourScale[typeMap[d]],
                    }}
                  >
                    {d}
                  </div>
                </div>
              );
            })
          )}
        </div>
        <div
          className="mb-6 inspirContainer  grid grid-cols-6	 flex-auto	 overflow-y-auto"
          style={{
            width: `${width}px`,
            height: "250px",
          }}
        ></div>
      </div>
    </div>
  );
}

export default App;
