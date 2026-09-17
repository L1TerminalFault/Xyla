#include <gtest/gtest.h>
#include "core/audio/graph/audioGraph.hpp"
#include "core/audio/nodes/masterOutputNode.hpp"
#include "core/audio/nodes/mixerTrackNode.hpp"

using namespace xyla::audio;

// ==============================================================================
// Pure Topology Tests (Zero Buffers, Zero Hardware)
// ==============================================================================
TEST(AudioGraphTopologyTest, AddAndRemoveSingleConnection) {
    std::vector<GraphConnection> conns;
    GraphConnection c1{"track_1", "audio_out", "master_out", "master_in"};

    EXPECT_TRUE(AudioGraphTopology::addConnection(conns, c1));
    // Adding duplicate connection must return false and not create duplicates
    EXPECT_FALSE(AudioGraphTopology::addConnection(conns, c1));
    EXPECT_EQ(conns.size(), 1u);

    EXPECT_TRUE(AudioGraphTopology::removeConnection(conns, c1));
    EXPECT_EQ(conns.size(), 0u);
    EXPECT_FALSE(AudioGraphTopology::removeConnection(conns, c1));
}

TEST(AudioGraphTopologyTest, ResolvesDiamondDependencyOrder) {
    // Diamond DAG:
    //      src
    //     /   \
    //   fx1   fx2
    //     \   /
    //      dst
    std::vector<std::string> nodes = {"dst", "fx1", "src", "fx2"};
    std::vector<GraphConnection> conns = {
        {"src", "out", "fx1", "in"},
        {"src", "out", "fx2", "in"},
        {"fx1", "out", "dst", "in"},
        {"fx2", "out", "dst", "in"}
    };

    auto order = AudioGraphTopology::computeTopologicalOrder(nodes, conns);
    ASSERT_EQ(order.size(), 4u);

    // 'src' must be the first node executed
    EXPECT_EQ(order[0], "src");
    // 'dst' must be the final node executed
    EXPECT_EQ(order[3], "dst");
}

// ==============================================================================
// AudioGraph Integration Tests
// ==============================================================================
TEST(AudioGraphTest, DuplicateNodeAdditionReturnsExistingInstance) {
    AudioGraph graph;
    auto *n1 = graph.addNode<MixerTrackNode>("track_voice", "Voice");
    auto *n2 = graph.addNode<MixerTrackNode>("track_voice", "Voice Alias");

    EXPECT_NE(n1, nullptr);
    EXPECT_EQ(n1, n2);
    EXPECT_EQ(graph.nodes().size(), 1u);
}

TEST(AudioGraphTest, CannotDeleteMasterNode) {
    AudioGraph graph;
    auto *master = graph.addNode<MasterOutputNode>("master_out");
    graph.setMasterNode(master);

    // Removing the designated master node must be rejected
    EXPECT_FALSE(graph.removeNode("master_out"));
    EXPECT_NE(graph.findNode("master_out"), nullptr);
}

TEST(AudioGraphTest, RemoveNodeDisconnectsAllAssociatedPins) {
    AudioGraph graph;
    graph.addNode<MixerTrackNode>("clip_0", "Clip");
    graph.addNode<MixerTrackNode>("track_0", "Track");
    graph.addNode<MasterOutputNode>("master_out");

    graph.connect("clip_0", "out", "track_0", "in");
    graph.connect("track_0", "out", "master_out", "in");
    EXPECT_EQ(graph.connections().size(), 2u);

    // Deleting track_0 must remove both incoming and outgoing connections
    EXPECT_TRUE(graph.removeNode("track_0"));
    EXPECT_EQ(graph.findNode("track_0"), nullptr);
    EXPECT_EQ(graph.connections().size(), 0u);
}
