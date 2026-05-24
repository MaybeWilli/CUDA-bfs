#include <iostream>
#include <vector>
#include <queue>
#include <random>

using namespace std;

class Bfs
{
    public:
        int nodes;
        vector<int> edges;
        vector<int> offsets;
        vector<int> dists;
        queue<int> v_queue;

        Bfs(int nodes, int mode);
        Bfs(int v_size, int* edges, int e_size, int* offsets);
        void create_graph(double rate, int mode);
        void solve(int start);
        void display();
};